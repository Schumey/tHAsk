import asyncio
from datetime import date, datetime, timedelta, timezone

import pytest

from core.collection import TaskCollection
from core.period import Granularity, Period
from core.triggers import CalendarEvent, EntityState, Trigger, TriggerBook, render_title, state_matches

TZ = timezone(timedelta(hours=1))
# Tuesday 3 Nov, 19:00.
NOW = datetime(2026, 11, 3, 19, 0, tzinfo=TZ)
TODAY = NOW.date()


class FakeSource:
    def __init__(self) -> None:
        self.states: dict[str, EntityState] = {}
        self.calendar: dict[str, list[CalendarEvent]] = {}
        self.requests = 0

    def state(self, entity_id):
        return self.states.get(entity_id)

    async def events(self, entity_id, start, end):
        self.requests += 1
        return list(self.calendar.get(entity_id, []))


@pytest.fixture
def collection():
    collection = TaskCollection()
    collection.create_list("Aufgaben")
    return collection


@pytest.fixture
def source():
    return FakeSource()


def shift(day: date, hour: int) -> CalendarEvent:
    start = datetime(day.year, day.month, day.day, hour, tzinfo=TZ)
    return CalendarEvent("Frühschicht", start, start + timedelta(hours=8))


def early_shift_trigger(book: TriggerBook, **fields) -> Trigger:
    return book.create(
        {
            "name": "Frühschicht",
            "conditions": [{"kind": "calendar", "entity": "calendar.arbeit", "match": "frühschicht", "part": "start"}],
            "days_ahead": 1,
            "task": {"title": "{termin} vorbereiten ({datum})", "due": "today"},
            **fields,
        }
    )


def check(book, collection, source, now=NOW):
    return asyncio.run(book.check(collection, source, now, "de"))


def titles(collection):
    return sorted(task.title for task in collection.tasks.values())


def test_calendar_event_tomorrow_creates_task_today(collection, source):
    book = TriggerBook()
    early_shift_trigger(book)
    source.calendar["calendar.arbeit"] = [shift(TODAY + timedelta(days=1), 6)]
    [run] = check(book, collection, source)
    assert run.day == "2026-11-04"
    task = collection.tasks[run.task_id]
    assert task.title == "Frühschicht vorbereiten (Mi, 4. Nov.)"
    assert task.due == Period.day(TODAY)
    # Once per day and event: checking again changes nothing, and the next day neither.
    assert check(book, collection, source) == []
    assert check(book, collection, source, NOW + timedelta(days=1)) == []
    assert len(collection.tasks) == 1


def test_multi_day_event_creates_one_task(collection, source):
    book = TriggerBook()
    book.create(
        {
            "name": "Urlaub",
            "conditions": [{"kind": "calendar", "entity": "calendar.privat", "match": "Urlaub"}],
            "days_ahead": 3,
            "task": {"title": "Blumen gießen lassen", "due": "day"},
        }
    )
    source.calendar["calendar.privat"] = [CalendarEvent("Urlaub", TODAY + timedelta(days=1), TODAY + timedelta(days=8))]
    [run] = check(book, collection, source)
    assert run.day == "2026-11-04"
    # Only one calendar request per check, however many days are looked at.
    assert source.requests == 1


def test_state_condition_with_hold_time_and_window(collection, source):
    book = TriggerBook()
    book.create(
        {
            "name": "Gym",
            "conditions": [{"kind": "state", "entity": "person.max", "match": "Fitnessstudio", "hold_minutes": 20}],
            "window_from": "06:00",
            "window_to": "21:00",
            "task": {"title": "Protein kaufen ({zustand})", "due": "none", "priority": 2},
        }
    )
    source.states["person.max"] = EntityState("fitnessstudio", NOW - timedelta(minutes=5))
    assert check(book, collection, source) == []
    source.states["person.max"] = EntityState("fitnessstudio", NOW - timedelta(minutes=25))
    assert check(book, collection, source, NOW.replace(hour=22)) == []
    [run] = check(book, collection, source)
    task = collection.tasks[run.task_id]
    assert (task.title, task.due, task.priority) == ("Protein kaufen (fitnessstudio)", None, 2)


def test_combine_and_or_with_negation(collection, source):
    book = TriggerBook()
    conditions = [
        {"kind": "time", "match": "18:00"},
        {"kind": "calendar", "entity": "calendar.arbeit", "match": "Frühschicht", "negate": True},
    ]
    trigger = book.create({"name": "Frei", "conditions": conditions, "task": {"title": "Ausschlafen"}})
    source.calendar["calendar.arbeit"] = [shift(TODAY, 6)]
    assert check(book, collection, source) == []
    book.update(trigger.id, {"combine": "or"})
    assert len(check(book, collection, source)) == 1


def test_paused_and_disabled(collection, source):
    book = TriggerBook()
    trigger = book.create({"name": "Abends", "conditions": [{"kind": "time", "match": "18:00"}], "task": {"title": "Müll"}})
    book.update(trigger.id, {"paused_until": "2026-11-03"})
    assert check(book, collection, source) == []
    book.update(trigger.id, {"paused_until": None, "enabled": False})
    assert check(book, collection, source) == []
    book.update(trigger.id, {"enabled": True})
    assert len(check(book, collection, source)) == 1


def test_undo_removes_task_and_blocks_the_day(collection, source):
    book = TriggerBook()
    book.create({"name": "Abends", "conditions": [{"kind": "time", "match": "18:00"}], "task": {"title": "Müll"}})
    [run] = check(book, collection, source)
    book.undo(run.id, collection)
    assert collection.tasks == {}
    assert book.runs[0].undone
    assert check(book, collection, source) == []


def test_missing_list_falls_back_to_default(collection, source):
    book = TriggerBook()
    trigger = book.create({"name": "x", "conditions": [{"kind": "time", "match": "00:00"}], "task": {"title": "x", "list_id": "gone"}})
    run = book.fire(trigger, collection, TODAY, TODAY, "de")
    assert collection.tasks[run.task_id].list_id == collection.default_list().id


def test_dump_and_load_roundtrip(collection, source):
    book = TriggerBook()
    early_shift_trigger(book)
    source.calendar["calendar.arbeit"] = [shift(TODAY, 6)]
    check(book, collection, source)
    copy = TriggerBook()
    copy.load(book.dump())
    assert copy.dump() == book.dump()


def test_state_matches():
    assert state_matches("on", "")
    assert state_matches("Home", "home")
    assert not state_matches("off", "")
    assert state_matches("21.5", ">20")
    assert state_matches("4,5", "<5")
    assert not state_matches("unavailable", ">=1")


def test_render_title():
    day = date(2026, 11, 4)
    assert render_title("{wochentag}: {datum}", None, day, "de", TODAY) == "Mittwoch: Mi, 4. Nov."
    assert render_title("Plan {unknown}", None, day, "de", TODAY) == "Plan {unknown}"


def test_due_the_day_before(collection, source):
    book = TriggerBook()
    early_shift_trigger(book, days_ahead=3, task={"title": "{termin} vorbereiten", "due": "day_before"})
    source.calendar["calendar.arbeit"] = [shift(TODAY + timedelta(days=3), 6), shift(TODAY, 14)]
    runs = check(book, collection, source)
    due = {run.day: collection.tasks[run.task_id].due for run in runs}
    # Created as soon as the event is in sight, due the day before it; today's event is due today.
    assert due == {"2026-11-03": Period.day(TODAY), "2026-11-06": Period.day(date(2026, 11, 5))}


def test_week_due_option(collection, source):
    book = TriggerBook()
    trigger = book.create({"name": "w", "conditions": [{"kind": "time", "match": "00:00"}], "task": {"title": "w", "due": "week"}})
    run = book.fire(trigger, collection, TODAY, TODAY, "de")
    assert collection.tasks[run.task_id].due == Period(Granularity.WEEK, TODAY)


def test_failing_calendar_is_reported_and_others_still_run(collection, source):
    class Broken(FakeSource):
        async def events(self, entity_id, start, end):
            raise RuntimeError("calendar.kaputt not found")

    book = TriggerBook()
    book.create({"name": "A", "conditions": [{"kind": "calendar", "entity": "calendar.kaputt"}], "task": {"title": "a"}})
    book.create({"name": "B", "conditions": [{"kind": "time", "match": "00:00"}], "task": {"title": "b"}})
    assert [run.title for run in check(book, collection, Broken())] == ["b"]
    assert book.errors == ["A: calendar.kaputt not found"]
