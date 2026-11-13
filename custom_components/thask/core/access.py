"""Who may see and change which list.

A list without members is for everyone. A list with members is only for them: other users neither
receive it nor its tasks, and cannot change them. Administrators see everything (they can read the
storage files anyway; the apps hide other people's lists from them by default). Calls without a user,
such as automations, are not restricted.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from .collection import Change, NotFoundError, TaskCollection
from .models import TaskList

if TYPE_CHECKING:
    # Anything with `id` and `is_admin` works; the tests use a stand-in.
    from homeassistant.auth.models import User


def can_access(user: User | None, task_list: TaskList | None) -> bool:
    if task_list is None:
        return False
    return user is None or user.is_admin or task_list.visible_to(user.id)


def visible_lists(user: User | None, collection: TaskCollection) -> list[TaskList]:
    return [task_list for task_list in collection.sorted_lists() if can_access(user, task_list)]


def check_list(user: User | None, collection: TaskCollection, list_id: str) -> None:
    """Raise if `user` may not use the list; an unknown list stays a "not found" error."""
    task_list = collection.lists.get(list_id)
    if task_list is None:
        raise NotFoundError(list_id)
    if not can_access(user, task_list):
        # Same answer as for a missing list, so ids of other people's lists give nothing away.
        raise NotFoundError(list_id)


def check_task(user: User | None, collection: TaskCollection, task_id: str) -> None:
    task = collection.tasks.get(task_id)
    if task is None:
        raise NotFoundError(task_id)
    if not can_access(user, collection.lists.get(task.list_id)):
        raise NotFoundError(task_id)



class ChangeFilter:
    """Which changes one subscriber gets: only lists they may see and the tasks in them.

    `apply` returns the change to send, a "removed" change when a task moved out of sight, None when
    the subscriber must not learn about it, or RESNAPSHOT when a list became visible or invisible
    (members changed); then a fresh snapshot replaces everything.
    """

    RESNAPSHOT = "snapshot"

    def __init__(self, user: User | None, collection: TaskCollection) -> None:
        self.user = user
        self.collection = collection
        self.visible: set[str] = set()
        # Tasks the subscriber knows, so a task moving out of sight can be reported as removed.
        self.known: set[str] = set()
        self.reset()

    def reset(self) -> None:
        self.visible = {task_list.id for task_list in visible_lists(self.user, self.collection)}
        self.known = {task.id for task in self.collection.tasks.values() if task.list_id in self.visible}

    def apply(self, change: Change) -> Change | str | None:
        if change.kind == "list":
            if change.action == "removed":
                if change.id not in self.visible:
                    return None
                self.visible.discard(change.id)
                return change
            now = can_access(self.user, self.collection.lists.get(change.id))
            if change.action == "created":
                if not now:
                    return None
                self.visible.add(change.id)
                return change
            if now != (change.id in self.visible):
                return self.RESNAPSHOT
            return change if now else None
        task = self.collection.tasks.get(change.id)
        if task is not None and task.list_id in self.visible:
            self.known.add(change.id)
            return change
        if change.id not in self.known:
            return None
        self.known.discard(change.id)
        # Deleted, or moved into a list the subscriber cannot see: for them it is gone.
        return change if task is None else Change("removed", "task", change.id, None, change.list_id)
