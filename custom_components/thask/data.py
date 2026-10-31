"""Runtime data: persistence, reminders and day change handling around the task collection."""

from __future__ import annotations

from datetime import date, datetime, timedelta, tzinfo
from functools import partial
from typing import Any

from homeassistant.config_entries import ConfigEntryState
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import async_track_point_in_utc_time, async_track_time_change
from homeassistant.helpers.storage import Store
from homeassistant.util import dt as dt_util

from .const import (
    DOMAIN,
    EVENT_REMINDER,
    EVENT_TASK_DUE,
    EVENT_TASK_OVERDUE,
    SAVE_DELAY,
    SIGNAL_DAY_CHANGED,
    STORAGE_KEY,
    STORAGE_VERSION,
)
from .core.collection import Change, TaskCollection
from .core.models import Task


@callback
def async_get_data(hass: HomeAssistant) -> ThaskData:
    """The data of the loaded tHAsk entry (there is only one)."""
    for entry in hass.config_entries.async_entries(DOMAIN):
        if entry.state is ConfigEntryState.LOADED:
            return entry.runtime_data
    raise HomeAssistantError("tHAsk is not loaded")


class ThaskData:
    def __init__(self, hass: HomeAssistant) -> None:
        self.hass = hass
        self.collection = TaskCollection()
        self._store: Store[dict[str, Any]] = Store(hass, STORAGE_VERSION, STORAGE_KEY)
        self._reminders: dict[str, CALLBACK_TYPE] = {}
        self._unsubs: list[CALLBACK_TYPE] = []

    @property
    def tz(self) -> tzinfo:
        return dt_util.get_default_time_zone()

    @property
    def today(self) -> date:
        return dt_util.now().date()

    @property
    def language(self) -> str:
        return self.hass.config.language or "en"

    async def async_start(self) -> None:
        if data := await self._store.async_load():
            self.collection.load(data)
        if not self.collection.lists:
            self.collection.create_list("Aufgaben" if self.language.startswith("de") else "Tasks")
            await self._store.async_save(self.collection.dump())
        self._unsubs.append(self.collection.subscribe(self._on_change))
        self._unsubs.append(
            async_track_time_change(self.hass, self._on_new_day, hour=0, minute=0, second=5)
        )
        for task in self.collection.tasks.values():
            self._schedule_reminder(task)

    async def async_stop(self) -> None:
        for unsub in [*self._unsubs, *self._reminders.values()]:
            unsub()
        self._unsubs.clear()
        self._reminders.clear()
        await self._store.async_save(self.collection.dump())

    def task_info(self, task: Task) -> dict[str, Any]:
        """Task data enriched with labels, for events, service responses and attributes."""
        task_list = self.collection.lists.get(task.list_id)
        info = task.as_dict()
        info["list_name"] = task_list.name if task_list else None
        info["due_label"] = task.due.label(self.language, self.today) if task.due else None
        info["due_end"] = task.due.end.isoformat() if task.due else None
        info["due_status"] = task.due.status(self.today).value if task.due else None
        return info

    @callback
    def _on_change(self, change: Change) -> None:
        self._store.async_delay_save(self.collection.dump, SAVE_DELAY)
        if change.kind != "task":
            return
        if change.action == "removed":
            if unsub := self._reminders.pop(change.id, None):
                unsub()
        else:
            self._schedule_reminder(self.collection.tasks[change.id])

    @callback
    def _schedule_reminder(self, task: Task) -> None:
        if unsub := self._reminders.pop(task.id, None):
            unsub()
        if task.completed or not task.reminder:
            return
        when = dt_util.parse_datetime(task.reminder)
        if when is None or when <= dt_util.utcnow():
            return
        self._reminders[task.id] = async_track_point_in_utc_time(
            self.hass, partial(self._fire_reminder, task.id), when
        )

    @callback
    def _fire_reminder(self, task_id: str, _now: datetime) -> None:
        self._reminders.pop(task_id, None)
        task = self.collection.tasks.get(task_id)
        if task and not task.completed:
            self.hass.bus.async_fire(EVENT_REMINDER, self.task_info(task))

    @callback
    def _on_new_day(self, _now: datetime) -> None:
        today = self.today
        yesterday = today - timedelta(days=1)
        for task in self.collection.tasks.values():
            if task.completed or task.due is None:
                continue
            if task.due.start == today:
                self.hass.bus.async_fire(EVENT_TASK_DUE, self.task_info(task))
            elif task.due.end == yesterday:
                self.hass.bus.async_fire(EVENT_TASK_OVERDUE, self.task_info(task))
        async_dispatcher_send(self.hass, SIGNAL_DAY_CHANGED)
