"""In-memory collection of lists and tasks with change notifications. Persistence is up to the caller."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Literal

from .models import Attachment, Task, TaskList, new_id, sort_tasks, utc_now_iso

DATA_VERSION = 1


class NotFoundError(KeyError):
    """A list or task id does not exist."""


@dataclass(frozen=True, slots=True)
class Change:
    action: Literal["created", "updated", "removed"]
    kind: Literal["list", "task"]
    id: str
    # Serialized object, None for removals.
    item: dict[str, Any] | None
    # List the task belongs (or belonged) to; for lists their own id.
    list_id: str

    def as_dict(self) -> dict[str, Any]:
        return {"action": self.action, "kind": self.kind, "id": self.id, "item": self.item, "list_id": self.list_id}


class TaskCollection:
    def __init__(self) -> None:
        self.lists: dict[str, TaskList] = {}
        self.tasks: dict[str, Task] = {}
        self._listeners: list[Callable[[Change], None]] = []

    # -- persistence -------------------------------------------------------

    def load(self, data: dict[str, Any]) -> None:
        self.lists = {item["id"]: TaskList.from_dict(item) for item in data.get("lists", [])}
        self.tasks = {item["id"]: Task.from_dict(item) for item in data.get("tasks", [])}

    def dump(self) -> dict[str, Any]:
        return {
            "version": DATA_VERSION,
            "lists": [item.as_dict() for item in self.lists.values()],
            "tasks": [item.as_dict() for item in self.tasks.values()],
        }

    # -- change notifications ----------------------------------------------

    def subscribe(self, listener: Callable[[Change], None]) -> Callable[[], None]:
        self._listeners.append(listener)
        return lambda: self._listeners.remove(listener)

    def _notify(self, change: Change) -> None:
        for listener in list(self._listeners):
            listener(change)

    def _task_changed(self, action: Literal["created", "updated"], task: Task) -> None:
        self._notify(Change(action, "task", task.id, task.as_dict(), task.list_id))

    # -- lists ---------------------------------------------------------------

    def get_list(self, list_id: str) -> TaskList:
        try:
            return self.lists[list_id]
        except KeyError:
            raise NotFoundError(list_id) from None

    def sorted_lists(self) -> list[TaskList]:
        return sorted(self.lists.values(), key=lambda item: (item.position, item.created))

    def default_list(self) -> TaskList | None:
        lists = self.sorted_lists()
        return lists[0] if lists else None

    def create_list(self, name: str, *, external_id: str | None = None, **fields: Any) -> TaskList:
        position = max((item.position for item in self.lists.values()), default=-1) + 1
        task_list = TaskList(id=new_id(), name=name, position=position, external_id=external_id)
        task_list.apply(fields)
        self.lists[task_list.id] = task_list
        self._notify(Change("created", "list", task_list.id, task_list.as_dict(), task_list.id))
        return task_list

    def update_list(self, list_id: str, patch: dict[str, Any]) -> TaskList:
        task_list = self.get_list(list_id)
        task_list.apply(patch)
        self._notify(Change("updated", "list", list_id, task_list.as_dict(), list_id))
        return task_list

    def delete_list(self, list_id: str) -> None:
        self.get_list(list_id)
        for task in self.tasks_in(list_id, include_completed=True):
            self.delete_task(task.id)
        del self.lists[list_id]
        self._notify(Change("removed", "list", list_id, None, list_id))

    def move_list(self, list_id: str, previous_id: str | None) -> TaskList:
        """Place a list directly after `previous_id`, or first when None."""
        task_list = self.get_list(list_id)
        order = [item for item in self.sorted_lists() if item.id != list_id]
        index = 0
        if previous_id is not None:
            index = next((i + 1 for i, item in enumerate(order) if item.id == previous_id), None)
            if index is None:
                raise NotFoundError(previous_id)
        order.insert(index, task_list)
        for position, item in enumerate(order):
            if item.position != position:
                item.apply({"position": position})
                self._notify(Change("updated", "list", item.id, item.as_dict(), item.id))
        return task_list

    def clear_completed(self, list_id: str | None = None, completed_before: datetime | None = None) -> int:
        """Delete completed tasks (of one list, or all), optionally only those completed before a time."""
        if list_id is not None:
            self.get_list(list_id)
        doomed = [
            task.id
            for task in self.tasks.values()
            if task.completed
            and (list_id is None or task.list_id == list_id)
            and (
                completed_before is None
                or (task.completed_at is not None and datetime.fromisoformat(task.completed_at) < completed_before)
            )
        ]
        for task_id in doomed:
            self.delete_task(task_id)
        return len(doomed)

    # -- tasks ---------------------------------------------------------------

    def get_task(self, task_id: str) -> Task:
        try:
            return self.tasks[task_id]
        except KeyError:
            raise NotFoundError(task_id) from None

    def tasks_in(self, list_id: str, include_completed: bool = True, sort: str = "manual") -> list[Task]:
        tasks = [
            task for task in self.tasks.values()
            if task.list_id == list_id and (include_completed or not task.completed)
        ]
        return sort_tasks(tasks, sort)

    def find_external_list(self, external_id: str) -> TaskList | None:
        return next((item for item in self.lists.values() if item.external_id == external_id), None)

    def find_external(self, external_id: str) -> Task | None:
        return next((task for task in self.tasks.values() if task.external_id == external_id), None)

    def create_task(self, list_id: str, title: str, *, external_id: str | None = None, **fields: Any) -> Task:
        """Create a task at the top of its list. `fields` are in serialized form."""
        self.get_list(list_id)
        task = Task(id=new_id(), list_id=list_id, title=title, position=self.top_position(list_id))
        task.external_id = external_id
        task.apply(fields)
        self.tasks[task.id] = task
        self._task_changed("created", task)
        return task

    def top_position(self, list_id: str) -> float:
        return min((task.position for task in self.tasks.values() if task.list_id == list_id), default=1) - 1

    def add_task(self, task: Task) -> Task:
        """Insert a fully built task (e.g. the next occurrence of a recurring one)."""
        self.get_list(task.list_id)
        self.tasks[task.id] = task
        self._task_changed("created", task)
        return task

    def update_task(self, task_id: str, patch: dict[str, Any], today: date) -> Task:
        """Apply a partial update. Completing a recurring task creates its next occurrence."""
        task = self.get_task(task_id)
        if "list_id" in patch:
            self.get_list(patch["list_id"])
        old_list_id = task.list_id
        was_completed = task.completed
        task.apply(patch)
        if old_list_id != task.list_id:
            self._notify(Change("removed", "task", task.id, None, old_list_id))
            self._task_changed("created", task)
        else:
            self._task_changed("updated", task)
        if task.completed and not was_completed and (following := task.next_occurrence(today)):
            self.add_task(following)
        return task

    def add_attachment(self, task_id: str, attachment: Attachment) -> Task:
        task = self.get_task(task_id)
        task.attachments.append(attachment)
        task.modified = utc_now_iso()
        self._task_changed("updated", task)
        return task

    def remove_attachment(self, task_id: str, attachment_id: str) -> Attachment:
        task = self.get_task(task_id)
        attachment = self.get_attachment(task_id, attachment_id)
        task.attachments.remove(attachment)
        task.modified = utc_now_iso()
        self._task_changed("updated", task)
        return attachment

    def get_attachment(self, task_id: str, attachment_id: str) -> Attachment:
        task = self.get_task(task_id)
        attachment = next((item for item in task.attachments if item.id == attachment_id), None)
        if attachment is None:
            raise NotFoundError(attachment_id)
        return attachment

    def delete_task(self, task_id: str) -> None:
        task = self.get_task(task_id)
        del self.tasks[task_id]
        self._notify(Change("removed", "task", task_id, None, task.list_id))

    def move_task(self, task_id: str, previous_id: str | None) -> Task:
        """Place a task directly after `previous_id` in its list, or first when None."""
        task = self.get_task(task_id)
        order = [item for item in self.tasks_in(task.list_id) if item.id != task_id]
        index = 0
        if previous_id is not None:
            index = next((i + 1 for i, item in enumerate(order) if item.id == previous_id), None)
            if index is None:
                raise NotFoundError(previous_id)
        order.insert(index, task)
        for position, item in enumerate(order):
            if item.position != position:
                item.position = position
                item.modified = utc_now_iso()
                self._task_changed("updated", item)
        return task
