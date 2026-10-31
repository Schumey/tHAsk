from datetime import date, datetime, timezone

import pytest

from core.collection import NotFoundError, TaskCollection
from core.models import Task
from core.period import Granularity, Period

TODAY = date(2026, 11, 3)


@pytest.fixture
def collection():
    collection = TaskCollection()
    collection.create_list("Aufgaben")
    return collection


@pytest.fixture
def list_id(collection):
    return collection.default_list().id


def test_new_tasks_go_on_top(collection, list_id):
    first = collection.create_task(list_id, "Erste")
    second = collection.create_task(list_id, "Zweite")
    assert [task.id for task in collection.tasks_in(list_id)] == [second.id, first.id]


def test_move(collection, list_id):
    a, b, c = (collection.create_task(list_id, title) for title in "abc")
    # Order is now c, b, a.
    collection.move_task(c.id, a.id)
    assert [task.title for task in collection.tasks_in(list_id)] == ["b", "a", "c"]
    collection.move_task(c.id, None)
    assert [task.title for task in collection.tasks_in(list_id)] == ["c", "b", "a"]
    with pytest.raises(NotFoundError):
        collection.move_task(c.id, "missing")


def test_completing_recurring_task_creates_next(collection, list_id):
    task = collection.create_task(
        list_id,
        "Rechnungen ablegen",
        due=Period.month(2026, 10).as_dict(),
        recurrence={"unit": "month", "interval": 1},
        steps=[{"title": "Scannen", "completed": True}],
    )
    collection.update_task(task.id, {"completed": True}, TODAY)
    assert task.completed and task.completed_at
    [following] = [item for item in collection.tasks.values() if not item.completed]
    # October was overdue, so the next occurrence is the current month, not one already over.
    assert following.due == Period.month(2026, 11)
    assert [step.completed for step in following.steps] == [False]


def test_completing_twice_does_not_duplicate(collection, list_id):
    task = collection.create_task(
        list_id, "Wöchentlich", due=Period.iso_week(2026, 45).as_dict(), recurrence={"unit": "week"}
    )
    collection.update_task(task.id, {"completed": True}, TODAY)
    collection.update_task(task.id, {"completed": True}, TODAY)
    assert len(collection.tasks) == 2


def test_due_by_includes_whole_period():
    task = Task(id="1", list_id="l", title="t", due=Period.month(2026, 11))
    week_end = Period(Granularity.WEEK, TODAY).end
    assert not task.due_by(week_end)
    assert task.due_by(date(2026, 11, 30))


def test_due_time_only_for_days(collection, list_id):
    task = collection.create_task(list_id, "t", due=Period.day(TODAY).as_dict(), due_time="09:30")
    assert task.due_time == "09:30"
    collection.update_task(task.id, {"due": Period.iso_week(2026, 45).as_dict()}, TODAY)
    assert task.due_time is None


def test_change_notifications_and_moves_between_lists(collection, list_id):
    other = collection.create_list("Einkauf")
    changes = []
    collection.subscribe(changes.append)
    task = collection.create_task(list_id, "Milch")
    collection.update_task(task.id, {"list_id": other.id}, TODAY)
    assert [(c.action, c.list_id) for c in changes] == [
        ("created", list_id),
        ("removed", list_id),
        ("created", other.id),
    ]


def test_dump_and_load_roundtrip(collection, list_id):
    collection.create_task(
        list_id,
        "Steuer",
        due=Period.quarter(2027, 1).as_dict(),
        important=True,
        reminder="2027-01-04T08:00:00+00:00",
        recurrence={"unit": "year", "interval": 1},
        categories=["Finanzen"],
    )
    restored = TaskCollection()
    restored.load(collection.dump())
    assert restored.dump() == collection.dump()


def test_delete_list_removes_tasks(collection, list_id):
    collection.create_task(list_id, "x")
    collection.delete_list(list_id)
    assert not collection.tasks and not collection.lists


def test_move_list(collection):
    first = collection.default_list()
    second = collection.create_list("Zwei")
    third = collection.create_list("Drei")
    collection.move_list(third.id, None)
    assert [item.name for item in collection.sorted_lists()] == ["Drei", "Aufgaben", "Zwei"]
    collection.move_list(third.id, second.id)
    assert [item.id for item in collection.sorted_lists()] == [first.id, second.id, third.id]


def test_clear_completed(collection, list_id):
    other = collection.create_list("Andere")
    old = collection.create_task(list_id, "alt")
    collection.update_task(old.id, {"completed": True}, TODAY)
    old.completed_at = "2026-01-01T00:00:00+00:00"
    new = collection.create_task(list_id, "neu")
    collection.update_task(new.id, {"completed": True}, TODAY)
    elsewhere = collection.create_task(other.id, "woanders")
    collection.update_task(elsewhere.id, {"completed": True}, TODAY)
    collection.create_task(list_id, "offen")

    assert collection.clear_completed(list_id, datetime(2026, 6, 1, tzinfo=timezone.utc)) == 1
    assert collection.clear_completed(list_id) == 1
    assert {task.title for task in collection.tasks.values()} == {"offen", "woanders"}
    assert collection.clear_completed() == 1


def test_sort_modes(collection, list_id):
    a = collection.create_task(list_id, "beta", due=Period.month(2026, 12).as_dict())
    b = collection.create_task(list_id, "Alpha", important=True)
    c = collection.create_task(list_id, "gamma", due=Period.day(TODAY).as_dict())
    titles = lambda mode: [task.title for task in collection.tasks_in(list_id, sort=mode)]  # noqa: E731
    assert titles("manual") == ["gamma", "Alpha", "beta"]
    assert titles("important") == ["Alpha", "gamma", "beta"]
    assert titles("due") == ["gamma", "beta", "Alpha"]
    assert titles("title") == ["Alpha", "beta", "gamma"]
    a.created, b.created, c.created = "2026-01-01", "2026-03-01", "2026-02-01"
    assert titles("created") == ["Alpha", "gamma", "beta"]
