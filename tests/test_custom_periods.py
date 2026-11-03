import asyncio
from datetime import date, datetime, timedelta, timezone

import pytest

from core.collection import TaskCollection
from core.custom_periods import PeriodBook, PeriodRule
from core.models import Recurrence, Task
from core.parser import parse
from core.period import Granularity, Period
from core.triggers import CalendarEvent

TZ = timezone(timedelta(hours=1))


def night(day: date) -> CalendarEvent:
    """A night shift from 20:00 on `day` to 6:00 the next morning."""
    start = datetime(day.year, day.month, day.day, 20, tzinfo=TZ)
    return CalendarEvent("Nachtschicht", start, start + timedelta(hours=10))


def shift(name: str, day: date) -> CalendarEvent:
    return CalendarEvent(name, day, day + timedelta(days=1))


def x_block_rule(**fields) -> PeriodRule:
    rule = PeriodRule(id="x", name="X-Block")
    rule.apply(
        {
            "calendar": "calendar.schichtplan",
            "anchor_match": "Nacht",
            "anchor_part": "end",
            "anchor_weekdays": [2],
            "start_offset": 1,
            "end_offset": 9,
            "max_events": 3,
            **fields,
        }
    )
    return rule


# Nights Mon 2 Nov – Tue 3 Nov end on Wednesday 4 Nov.
NIGHTS = [night(date(2026, 11, 2)), night(date(2026, 11, 3))]
TODAY = date(2026, 11, 3)


def test_x_block_after_night_shift_ending_wednesday():
    events = [*NIGHTS, shift("Früh", date(2026, 11, 9)), shift("Früh", date(2026, 11, 10))]
    found = x_block_rule().find(events, TZ, TODAY)
    # Thursday 5 Nov to the Friday after next, 13 Nov.
    assert found == [Period.custom(date(2026, 11, 5), date(2026, 11, 13), "X-Block", "x")]
    assert found[0].label("de", TODAY) == "X-Block 5. Nov."


def test_too_many_events_is_no_x_block():
    events = [*NIGHTS, *(shift("Früh", date(2026, 11, 6) + timedelta(days=n)) for n in range(4))]
    assert x_block_rule().find(events, TZ, TODAY) == []
    # Only events whose title contains the text are counted.
    assert x_block_rule(count_match="Spät").find(events, TZ, TODAY) != []
    assert x_block_rule(max_events=None).find(events, TZ, TODAY) != []


def test_anchor_weekday_and_part():
    # The night Tue 3 Nov ends on Wednesday, the one of Mon 2 Nov on Tuesday: only one anchor.
    assert len(x_block_rule().find(NIGHTS, TZ, TODAY)) == 1
    # Without a weekday every last day counts; the earlier anchor gives an overlapping block of its own.
    assert len(x_block_rule(anchor_weekdays=[]).find(NIGHTS, TZ, TODAY)) == 2
    # The nights start on Monday and Tuesday, not on a Wednesday.
    assert x_block_rule(anchor_part="start").find(NIGHTS, TZ, TODAY) == []
    assert len(x_block_rule(anchor_part="start", anchor_weekdays=[1]).find(NIGHTS, TZ, TODAY)) == 1


def test_running_period_is_kept_ended_one_dropped():
    found = x_block_rule().find(NIGHTS, TZ, date(2026, 11, 13))
    assert len(found) == 1
    assert x_block_rule().find(NIGHTS, TZ, date(2026, 11, 14)) == []


def test_window_reaches_back_for_running_periods():
    start, end = x_block_rule().window(TODAY)
    assert start <= TODAY - timedelta(days=9)
    assert end >= TODAY + timedelta(days=120)


def test_rule_values_are_clamped():
    rule = x_block_rule(start_offset=5, end_offset=2, anchor_weekdays=[9, 2, 2], max_events="")
    assert (rule.start_offset, rule.end_offset) == (5, 5)
    assert rule.anchor_weekdays == (2,)
    assert rule.max_events is None


class FakeSource:
    def __init__(self, events, fail=False):
        self._events, self.fail = events, fail

    def state(self, entity_id):
        return None

    async def events(self, entity_id, start, end):
        if self.fail:
            raise RuntimeError("calendar.schichtplan not found")
        return self._events


def test_book_refresh_keeps_periods_on_error_and_round_trips():
    book = PeriodBook()
    rule = book.create(x_block_rule().as_dict() | {"name": "X-Block"})
    asyncio.run(book.refresh(FakeSource(NIGHTS), TODAY, TZ))
    assert [p.start for p in book.upcoming(rule.id, TODAY)] == [date(2026, 11, 5)]
    asyncio.run(book.refresh(FakeSource([], fail=True), TODAY, TZ))
    assert book.errors[rule.id]
    assert len(book.upcoming(rule.id, TODAY)) == 1

    copy = PeriodBook()
    copy.load(book.dump())
    assert copy.upcoming(rule.id, TODAY) == book.upcoming(rule.id, TODAY)
    assert copy.public(TODAY)[0]["instances"][0]["end"] == "2026-11-13"

    book.update(rule.id, {"name": "Frei"})
    assert book.upcoming(rule.id, TODAY)[0].name == "Frei"


def test_period_custom_serialization_and_shift():
    period = Period.custom(date(2026, 11, 5), date(2026, 11, 13), "X-Block", "x")
    assert Period.from_dict(period.as_dict()) == period
    assert period.end == date(2026, 11, 13)
    assert period.shift(1) == Period.custom(date(2026, 11, 14), date(2026, 11, 22), "X-Block", "x")
    assert period.shift(1, Granularity.WEEK).start == date(2026, 11, 12)
    # Other granularities have no end, name or rule of their own.
    assert Period(Granularity.WEEK, date(2026, 11, 5), date(2027, 1, 1), "x").as_dict() == {
        "granularity": "week",
        "start": "2026-11-02",
    }


BLOCKS = [
    Period.custom(date(2026, 11, 1), date(2026, 11, 6), "X-Block", "x"),
    Period.custom(date(2026, 11, 20), date(2026, 11, 28), "X-Block", "x"),
    Period.custom(date(2026, 12, 18), date(2026, 12, 26), "X-Block", "x"),
]


@pytest.mark.parametrize(
    ("text", "title", "start"),
    [
        ("Rasen mähen im X-Block", "Rasen mähen", date(2026, 11, 1)),
        ("Rasen mähen nächster X-Block", "Rasen mähen", date(2026, 11, 20)),
        ("Rasen mähen im nächsten x-block", "Rasen mähen", date(2026, 11, 20)),
        ("Keller übernächster X-Block", "Keller", date(2026, 12, 18)),
        ("Mow lawn next X-Block", "Mow lawn", date(2026, 11, 20)),
    ],
)
def test_parser_custom_period(text, title, start):
    result = parse(text, TODAY, custom=[("X-Block", BLOCKS)])
    assert result.title == title
    assert result.due.start == start
    assert result.due.granularity is Granularity.CUSTOM


def test_parser_custom_recurrence_and_unknown_name():
    result = parse("Großeinkauf jeden X-Block", TODAY, custom=[("X-Block", BLOCKS)])
    assert result.title == "Großeinkauf"
    assert result.recurrence.unit is Granularity.CUSTOM
    assert result.due == BLOCKS[0]
    assert parse("Rasen im X-Block", TODAY).due is None


def test_completing_every_x_block_task_moves_to_next_block():
    collection = TaskCollection()
    task_list = collection.create_list("Haus")
    collection.custom_resolver = lambda rule, after, today: next(
        (p for p in BLOCKS if p.rule == rule and p.start > after and p.end >= today), None
    )
    task = collection.create_task(
        task_list.id, "Großeinkauf", due=BLOCKS[0].as_dict(), recurrence=Recurrence(Granularity.CUSTOM).as_dict()
    )
    collection.update_task(task.id, {"completed": True}, TODAY)
    following = next(t for t in collection.tasks.values() if not t.completed)
    assert following.due == BLOCKS[1]


def test_every_x_block_without_found_period_keeps_length():
    task = Task(id="t", list_id="l", title="x", due=BLOCKS[2], recurrence=Recurrence(Granularity.CUSTOM))
    following = task.next_occurrence(TODAY, lambda rule, after, today: None)
    assert (following.due.start, following.due.end) == (date(2026, 12, 27), date(2027, 1, 4))
