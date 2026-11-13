"""Lists for certain people: who sees and changes what (core/access.py)."""

from dataclasses import dataclass
from datetime import date

import pytest

from core.access import ChangeFilter, can_access, check_list, check_task, visible_lists
from core.collection import NotFoundError, TaskCollection

TODAY = date(2026, 11, 6)


@dataclass
class User:
    id: str
    is_admin: bool = False


ANNA = User("anna")
MAX = User("max")
ADMIN = User("admin", is_admin=True)


@pytest.fixture
def collection():
    collection = TaskCollection()
    collection.create_list("Alle")
    collection.create_list("Anna", members=["anna"])
    return collection


def ids(collection, name):
    return next(task_list.id for task_list in collection.lists.values() if task_list.name == name)


def test_who_sees_which_list(collection):
    anna = collection.lists[ids(collection, "Anna")]
    assert can_access(ANNA, anna)
    assert not can_access(MAX, anna)
    assert can_access(ADMIN, anna)
    # Automations and other calls without a user are not restricted.
    assert can_access(None, anna)
    assert [task_list.name for task_list in visible_lists(MAX, collection)] == ["Alle"]
    assert [task_list.name for task_list in visible_lists(ANNA, collection)] == ["Alle", "Anna"]


def test_others_lists_and_tasks_look_missing(collection):
    task = collection.create_task(ids(collection, "Anna"), "Geschenk")
    with pytest.raises(NotFoundError):
        check_list(MAX, collection, ids(collection, "Anna"))
    with pytest.raises(NotFoundError):
        check_task(MAX, collection, task.id)
    check_task(ANNA, collection, task.id)
    check_task(ADMIN, collection, task.id)
    with pytest.raises(NotFoundError):
        check_task(ANNA, collection, "unknown")


def test_changes_only_reach_people_who_may_see_the_list(collection):
    seen = []
    changes = ChangeFilter(MAX, collection)
    collection.subscribe(lambda change: seen.append(changes.apply(change)))

    task = collection.create_task(ids(collection, "Anna"), "Geschenk")
    collection.update_task(task.id, {"title": "Geschenk für Max"}, TODAY)
    collection.delete_task(task.id)
    assert seen == [None, None, None]

    shared = collection.create_task(ids(collection, "Alle"), "Einkaufen")
    assert seen[-1].action == "created" and seen[-1].id == shared.id

    # Moved into Anna's list: for Max the task is gone, and he hears nothing about it afterwards.
    before = len(seen)
    collection.update_task(shared.id, {"list_id": ids(collection, "Anna")}, TODAY)
    collection.update_task(shared.id, {"title": "Einkaufen für Anna"}, TODAY)
    sent = [change for change in seen[before:] if change is not None]
    assert [(change.action, change.id, change.item) for change in sent] == [("removed", shared.id, None)]


def test_members_changing_asks_for_a_new_snapshot(collection):
    seen = []
    changes = ChangeFilter(MAX, collection)
    collection.subscribe(lambda change: seen.append(changes.apply(change)))

    collection.update_list(ids(collection, "Anna"), {"members": ["anna", "max"]})
    assert seen[-1] == ChangeFilter.RESNAPSHOT
    changes.reset()
    assert ids(collection, "Anna") in changes.visible

    collection.update_list(ids(collection, "Anna"), {"name": "Anna und Max"})
    assert seen[-1].action == "updated"

    collection.update_list(ids(collection, "Anna und Max"), {"members": ["anna"]})
    assert seen[-1] == ChangeFilter.RESNAPSHOT


def test_removed_list_is_forwarded_once(collection):
    seen = []
    changes = ChangeFilter(MAX, collection)
    collection.subscribe(lambda change: seen.append(changes.apply(change)))
    collection.delete_list(ids(collection, "Anna"))
    assert seen == [None]
    collection.create_list("Neu")
    collection.delete_list(ids(collection, "Neu"))
    assert seen[-1].action == "removed"
