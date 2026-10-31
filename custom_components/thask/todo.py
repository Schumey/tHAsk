"""Todo entities: one per task list plus the smart lists "Today", "Overdue" and "This week"."""

from __future__ import annotations

from datetime import date, datetime, time, tzinfo
from typing import TYPE_CHECKING, Any

from homeassistant.components.todo import (
    TodoItem,
    TodoItemStatus,
    TodoListEntity,
    TodoListEntityFeature,
)
from homeassistant.core import HomeAssistant, callback
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.device_registry import DeviceEntryType, DeviceInfo
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .const import DOMAIN, SIGNAL_DAY_CHANGED, SIGNAL_OPTIONS_CHANGED
from .core.collection import Change, NotFoundError
from .core.models import Task
from .core.period import Granularity, Period, PeriodStatus
from .data import ThaskData

if TYPE_CHECKING:
    from . import ThaskConfigEntry

PARALLEL_UPDATES = 0

# Completed tasks shown in Home Assistant per list; the apps see all of them.
MAX_COMPLETED_ITEMS = 100

# "Today" keeps the key of the former "My Day", so its entity id stays the same.
SMART_MY_DAY = "my_day"
SMART_THIS_WEEK = "this_week"
SMART_OVERDUE = "overdue"


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ThaskConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    data = entry.runtime_data
    async_add_entities(
        [
            ThaskSmartListEntity(entry, data, SMART_MY_DAY),
            ThaskSmartListEntity(entry, data, SMART_OVERDUE),
            ThaskSmartListEntity(entry, data, SMART_THIS_WEEK),
            *(ThaskListEntity(entry, data, task_list.id) for task_list in data.collection.sorted_lists()),
        ]
    )

    @callback
    def on_change(change: Change) -> None:
        if change.kind == "list" and change.action == "created":
            async_add_entities([ThaskListEntity(entry, data, change.id)])

    entry.async_on_unload(data.collection.subscribe(on_change))


def due_to_ha(task: Task, tz: tzinfo) -> date | datetime | None:
    """Home Assistant only knows exact dates, so a period is exported as its last day."""
    if task.due is None:
        return None
    if task.due.granularity is Granularity.DAY and task.due_time:
        return datetime.combine(task.due.start, time.fromisoformat(task.due_time), tzinfo=tz)
    return task.due.end


def due_from_ha(value: date | datetime | None, tz: tzinfo) -> dict[str, Any]:
    if value is None:
        return {"due": None, "due_time": None}
    if isinstance(value, datetime):
        local = value.astimezone(tz)
        return {"due": Period.day(local.date()).as_dict(), "due_time": local.strftime("%H:%M")}
    return {"due": Period.day(value).as_dict(), "due_time": None}


class ThaskTodoEntity(TodoListEntity):
    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, entry: ThaskConfigEntry, data: ThaskData) -> None:
        self._data = data
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, entry.entry_id)},
            name="tHAsk",
            manufacturer="tHAsk",
            entry_type=DeviceEntryType.SERVICE,
        )

    def _tasks(self) -> list[Task]:
        raise NotImplementedError

    def _is_relevant(self, change: Change) -> bool:
        raise NotImplementedError

    @callback
    def _handle_change(self, change: Change) -> None:
        if self._is_relevant(change):
            self.async_write_ha_state()

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(self._data.collection.subscribe(self._handle_change))
        self.async_on_remove(
            async_dispatcher_connect(self.hass, SIGNAL_DAY_CHANGED, self.async_write_ha_state)
        )
        self.async_on_remove(
            async_dispatcher_connect(self.hass, SIGNAL_OPTIONS_CHANGED, self.async_write_ha_state)
        )

    @property
    def todo_items(self) -> list[TodoItem]:
        return [self._to_item(task) for task in self._tasks()]

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        today = self._data.today
        open_tasks = [task for task in self._tasks() if not task.completed and task.due]
        return {
            "overdue": sum(task.due.status(today) is PeriodStatus.OVERDUE for task in open_tasks),
            "due_today": sum(task.due.end == today for task in open_tasks),
        }

    def _to_item(self, task: Task) -> TodoItem:
        return TodoItem(
            uid=task.id,
            summary=task.title,
            status=TodoItemStatus.COMPLETED if task.completed else TodoItemStatus.NEEDS_ACTION,
            due=due_to_ha(task, self._data.tz),
            description=task.notes or None,
            completed=datetime.fromisoformat(task.completed_at) if task.completed_at else None,
        )

    def _get_task(self, uid: str | None) -> Task:
        try:
            return self._data.collection.get_task(uid or "")
        except NotFoundError:
            raise ServiceValidationError(f"Task {uid} not found") from None

    def _sorted(self, tasks: list[Task]) -> list[Task]:
        open_tasks = [task for task in tasks if not task.completed]
        done = sorted(
            (task for task in tasks if task.completed),
            key=lambda task: task.completed_at or "",
            reverse=True,
        )
        return open_tasks + done[:MAX_COMPLETED_ITEMS]

    async def async_update_todo_item(self, item: TodoItem) -> None:
        task = self._get_task(item.uid)
        patch: dict[str, Any] = {
            "completed": item.status == TodoItemStatus.COMPLETED,
            "notes": item.description or "",
        }
        if item.summary is not None:
            patch["title"] = item.summary
        # Keep the fuzzy period unless the date was actually changed in Home Assistant.
        if item.due != due_to_ha(task, self._data.tz):
            patch.update(due_from_ha(item.due, self._data.tz))
        self._data.collection.update_task(task.id, patch, self._data.today)


class ThaskListEntity(ThaskTodoEntity):
    _attr_supported_features = (
        TodoListEntityFeature.CREATE_TODO_ITEM
        | TodoListEntityFeature.DELETE_TODO_ITEM
        | TodoListEntityFeature.UPDATE_TODO_ITEM
        | TodoListEntityFeature.MOVE_TODO_ITEM
        | TodoListEntityFeature.SET_DUE_DATE_ON_ITEM
        | TodoListEntityFeature.SET_DUE_DATETIME_ON_ITEM
        | TodoListEntityFeature.SET_DESCRIPTION_ON_ITEM
    )

    def __init__(self, entry: ThaskConfigEntry, data: ThaskData, list_id: str) -> None:
        super().__init__(entry, data)
        self._list_id = list_id
        self._attr_unique_id = list_id

    @property
    def name(self) -> str:
        task_list = self._data.collection.lists.get(self._list_id)
        return task_list.name if task_list else self._list_id

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        return {**super().extra_state_attributes, "list_id": self._list_id}

    def _tasks(self) -> list[Task]:
        task_list = self._data.collection.lists.get(self._list_id)
        sort = task_list.sort if task_list else "manual"
        return self._sorted(self._data.collection.tasks_in(self._list_id, sort=sort))

    def _is_relevant(self, change: Change) -> bool:
        return change.list_id == self._list_id

    @callback
    def _handle_change(self, change: Change) -> None:
        if change.kind == "list" and change.id == self._list_id and change.action == "removed":
            er.async_get(self.hass).async_remove(self.entity_id)
            return
        super()._handle_change(change)

    async def async_create_todo_item(self, item: TodoItem) -> None:
        fields: dict[str, Any] = {"notes": item.description or ""}
        if item.due is not None:
            fields.update(due_from_ha(item.due, self._data.tz))
        self._data.collection.create_task(self._list_id, item.summary or "", **fields)

    async def async_delete_todo_items(self, uids: list[str]) -> None:
        for uid in uids:
            self._data.collection.delete_task(self._get_task(uid).id)

    async def async_move_todo_item(self, uid: str, previous_uid: str | None = None) -> None:
        try:
            self._data.collection.move_task(self._get_task(uid).id, previous_uid)
        except NotFoundError:
            raise ServiceValidationError(f"Task {previous_uid} not found") from None


class ThaskSmartListEntity(ThaskTodoEntity):
    """Tasks from all lists. New tasks go to the first list."""

    _attr_supported_features = (
        TodoListEntityFeature.CREATE_TODO_ITEM
        | TodoListEntityFeature.UPDATE_TODO_ITEM
        | TodoListEntityFeature.SET_DUE_DATE_ON_ITEM
        | TodoListEntityFeature.SET_DUE_DATETIME_ON_ITEM
        | TodoListEntityFeature.SET_DESCRIPTION_ON_ITEM
    )

    def __init__(self, entry: ThaskConfigEntry, data: ThaskData, key: str) -> None:
        super().__init__(entry, data)
        self._key = key
        self._attr_translation_key = key
        self._attr_unique_id = f"{entry.entry_id}_{key}"

    def _matches(self, task: Task, today: date) -> bool:
        if self._key == SMART_MY_DAY:
            return task.in_today(today, self._data.tz, overdue=self._data.overdue_mode != "separate")
        if self._key == SMART_OVERDUE:
            return task.overdue(today)
        week_end = Period(Granularity.WEEK, today).end
        if task.completed:
            return task.due_by(week_end) and task.completed_on_or_after(
                Period(Granularity.WEEK, today).start, self._data.tz
            )
        return task.due_by(week_end)

    def _tasks(self) -> list[Task]:
        today = self._data.today
        tasks = [task for task in self._data.collection.tasks.values() if self._matches(task, today)]
        if self._key in (SMART_THIS_WEEK, SMART_OVERDUE):
            tasks.sort(key=lambda task: (task.due.end, -task.priority, task.position))
        else:
            tasks.sort(key=lambda task: (-task.priority, task.position))
        return self._sorted(tasks)

    def _is_relevant(self, change: Change) -> bool:
        return change.kind == "task"

    async def async_create_todo_item(self, item: TodoItem) -> None:
        default = self._data.collection.default_list()
        if default is None:
            raise ServiceValidationError("There is no task list to add the task to")
        today = self._data.today
        fields: dict[str, Any] = {"notes": item.description or ""}
        if item.due is not None:
            fields.update(due_from_ha(item.due, self._data.tz))
        elif self._key == SMART_THIS_WEEK:
            fields["due"] = Period(Granularity.WEEK, today).as_dict()
        elif self._key in (SMART_MY_DAY, SMART_OVERDUE):
            fields["due"] = Period.day(today).as_dict()
        self._data.collection.create_task(default.id, item.summary or "", **fields)
