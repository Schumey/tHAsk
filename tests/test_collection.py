from datetime import date, datetime, timezone

import pytest

from core.collection import NotFoundError, TaskCollection
from core.models import Task, TaskList
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


def next_due(collection, task):
    collection.update_task(task.id, {"completed": True}, TODAY)
    return next(item for item in collection.tasks.values() if not item.completed and item.title == task.title)


def test_recurrence_on_several_weekdays(collection, list_id):
    # Wednesday and Saturday; TODAY is Tuesday 3 Nov.
    recurrence = {"unit": "week", "interval": 1, "weekdays": [5, 2]}
    task = collection.create_task(list_id, "Blumen", due=Period.day(date(2026, 11, 4)).as_dict(), recurrence=recurrence)
    task = next_due(collection, task)
    assert task.due == Period.day(date(2026, 11, 7))
    assert task.recurrence.weekdays == (2, 5)
    assert next_due(collection, task).due == Period.day(date(2026, 11, 11))

    # Overdue since October: the next one is the first matching day from today on.
    task = collection.create_task(list_id, "Alt", due=Period.day(date(2026, 10, 3)).as_dict(), recurrence=recurrence)
    assert next_due(collection, task).due == Period.day(date(2026, 11, 4))


def test_every_other_week_on_weekdays(collection, list_id):
    # Monday and Thursday every other week, starting Monday 2 Nov.
    recurrence = {"unit": "week", "interval": 2, "weekdays": [0, 3]}
    task = collection.create_task(list_id, "Training", due=Period.day(date(2026, 11, 2)).as_dict(), recurrence=recurrence)
    task = next_due(collection, task)
    assert task.due == Period.day(date(2026, 11, 5))
    assert next_due(collection, task).due == Period.day(date(2026, 11, 16))


def test_weekdays_only_for_weekly_recurrences():
    task = Task(id="1", list_id="l", title="t")
    task.apply({"recurrence": {"unit": "month", "weekdays": [1, 2]}})
    assert task.recurrence.weekdays == ()
    assert "weekdays" not in task.as_dict()["recurrence"]


def test_completing_twice_does_not_duplicate(collection, list_id):
    task = collection.create_task(
        list_id, "Wöchentlich", due=Period.iso_week(2026, 45).as_dict(), recurrence={"unit": "week"}
    )
    collection.update_task(task.id, {"completed": True}, TODAY)
    collection.update_task(task.id, {"completed": True}, TODAY)
    assert len(collection.tasks) == 2


def test_today_shows_what_is_due():
    tz = timezone.utc
    due_today = Task(id="1", list_id="l", title="t", due=Period.day(TODAY))
    overdue = Task(id="2", list_id="l", title="t", due=Period.day(date(2026, 11, 1)))
    # A week ending today (Sunday) is due today; one ending later is not.
    week_ends_today = Task(id="3", list_id="l", title="t", due=Period.iso_week(2026, 45))
    tomorrow = Task(id="4", list_id="l", title="t", due=Period.day(date(2026, 11, 4)))
    undated = Task(id="5", list_id="l", title="t")
    sunday = date(2026, 11, 8)
    assert due_today.in_today(TODAY, tz) and overdue.in_today(TODAY, tz)
    assert week_ends_today.in_today(sunday, tz) and not week_ends_today.in_today(TODAY, tz)
    assert not tomorrow.in_today(TODAY, tz) and not undated.in_today(TODAY, tz)
    done_today = Task(id="6", list_id="l", title="t", due=Period.day(TODAY), completed=True,
                      completed_at=datetime(2026, 11, 3, 9, tzinfo=tz).isoformat())
    done_earlier = Task(id="7", list_id="l", title="t", due=Period.day(date(2026, 11, 1)), completed=True,
                        completed_at=datetime(2026, 11, 1, 9, tzinfo=tz).isoformat())
    assert done_today.in_today(TODAY, tz) and not done_earlier.in_today(TODAY, tz)


def test_overdue_can_be_left_out_of_today():
    tz = timezone.utc
    overdue = Task(id="1", list_id="l", title="t", due=Period.day(date(2026, 11, 1)))
    due_today = Task(id="2", list_id="l", title="t", due=Period.day(TODAY))
    done_late = Task(id="3", list_id="l", title="t", due=Period.day(date(2026, 11, 1)), completed=True,
                     completed_at=datetime(2026, 11, 3, 9, tzinfo=tz).isoformat())
    assert overdue.overdue(TODAY) and not due_today.overdue(TODAY) and not done_late.overdue(TODAY)
    assert not overdue.in_today(TODAY, tz, overdue=False)
    assert due_today.in_today(TODAY, tz, overdue=False)
    # Completed today, though late: it stays in "Today" so the day's work is visible.
    assert done_late.in_today(TODAY, tz, overdue=False)


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
        priority=2,
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
    b = collection.create_task(list_id, "Alpha", priority=3)
    c = collection.create_task(list_id, "gamma", due=Period.day(TODAY).as_dict())
    titles = lambda mode: [task.title for task in collection.tasks_in(list_id, sort=mode)]  # noqa: E731
    assert titles("manual") == ["gamma", "Alpha", "beta"]
    assert titles("priority") == ["Alpha", "gamma", "beta"]
    assert titles("due") == ["gamma", "beta", "Alpha"]
    assert titles("title") == ["Alpha", "beta", "gamma"]
    a.created, b.created, c.created = "2026-01-01", "2026-03-01", "2026-02-01"
    assert titles("created") == ["Alpha", "gamma", "beta"]


def test_legacy_important_flag_becomes_high_priority(collection, list_id):
    task = collection.create_task(list_id, "Alt", important=True)
    assert task.priority == 3 and task.as_dict()["important"] is True
    collection.update_task(task.id, {"important": False}, TODAY)
    assert task.priority == 0
    collection.update_task(task.id, {"priority": 2}, TODAY)
    assert task.priority == 2 and task.as_dict()["important"] is False

    stored = {"lists": [{"id": "l1", "name": "Alt", "sort": "important"}],
              "tasks": [{"id": "t1", "list_id": "l1", "title": "Wichtig", "important": True},
                        {"id": "t2", "list_id": "l1", "title": "Normal"}]}
    collection.load(stored)
    assert collection.tasks["t1"].priority == 3 and collection.tasks["t2"].priority == 0
    assert collection.lists["l1"].sort == "priority"


def test_views_kept_apart():
    """Options "separate_week" and "separate_month"; Sunday, 1 November 2026, the last day of week 44."""
    sunday = date(2026, 11, 1)
    utc = timezone.utc

    def task(task_id, due):
        return Task(id=task_id, list_id="l", title=task_id, due=due)

    today = task("today", Period.day(sunday))
    week = task("week 44", Period.iso_week(2026, 44))
    overdue = task("overdue", Period.day(date(2026, 10, 30)))
    november = task("november", Period.month(2026, 11))
    later = task("later", Period.day(date(2026, 11, 20)))

    def names(check):
        return {t.title for t in (today, week, overdue, november, later) if check(t)}

    assert names(lambda t: t.in_today(sunday, utc)) == {"today", "week 44", "overdue"}
    assert names(lambda t: t.in_today(sunday, utc, days_only=True)) == {"today", "overdue"}
    assert names(lambda t: t.in_this_week(sunday, utc)) == {"today", "week 44", "overdue"}
    assert names(lambda t: t.in_this_week(sunday, utc, separate=True)) == {"week 44"}
    assert names(lambda t: t.in_this_month(sunday, utc)) == {"today", "week 44", "overdue", "november", "later"}
    assert names(lambda t: t.in_this_month(sunday, utc, separate=True)) == {"november", "later"}


def test_this_week_as_next_seven_days():
    """Option "week_mode": "rolling". On Sunday, 1 November 2026, the next week is already in it."""
    sunday = date(2026, 11, 1)
    utc = timezone.utc
    next_week = Task(id="1", list_id="l", title="KW 45", due=Period.iso_week(2026, 45))
    monday = Task(id="2", list_id="l", title="Mo", due=Period.day(date(2026, 11, 2)))
    far = Task(id="3", list_id="l", title="far", due=Period.day(date(2026, 11, 9)))
    assert not next_week.in_this_week(sunday, utc)
    assert not monday.in_this_week(sunday, utc)
    assert next_week.in_this_week(sunday, utc, rolling=True)
    assert monday.in_this_week(sunday, utc, rolling=True)
    assert not far.in_this_week(sunday, utc, rolling=True)
    # Kept apart, "This month" starts after the rolling week.
    assert monday.in_this_month(sunday, utc, separate=True)
    assert not monday.in_this_month(sunday, utc, separate=True, rolling=True)
    assert far.in_this_month(sunday, utc, separate=True, rolling=True)


def test_list_members_for_the_overview() -> None:
    collection = TaskCollection()
    task_list = collection.create_list("Büro", members=["anna", "anna", "ben"])
    assert task_list.members == ["anna", "ben"]
    assert task_list.visible_to("anna") and not task_list.visible_to("carla")
    assert task_list.visible_to(None), "unknown users see everything"
    assert TaskList.from_dict(task_list.as_dict()).members == ["anna", "ben"]
    collection.update_list(task_list.id, {"members": []})
    assert task_list.visible_to("carla")
    # Lists stored before members existed are for everyone.
    old = task_list.as_dict()
    del old["members"]
    assert TaskList.from_dict(old).visible_to("carla")
