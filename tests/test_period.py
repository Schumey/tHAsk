from datetime import date

import pytest

from core.period import Granularity, Period, PeriodStatus


@pytest.mark.parametrize(
    ("granularity", "day", "start", "end"),
    [
        (Granularity.DAY, date(2026, 11, 12), date(2026, 11, 12), date(2026, 11, 12)),
        (Granularity.WEEK, date(2026, 11, 12), date(2026, 11, 9), date(2026, 11, 15)),
        (Granularity.WEEK, date(2026, 12, 31), date(2026, 12, 28), date(2027, 1, 3)),
        (Granularity.MONTH, date(2028, 2, 10), date(2028, 2, 1), date(2028, 2, 29)),
        (Granularity.QUARTER, date(2026, 11, 12), date(2026, 10, 1), date(2026, 12, 31)),
        (Granularity.YEAR, date(2026, 11, 12), date(2026, 1, 1), date(2026, 12, 31)),
    ],
)
def test_bounds(granularity, day, start, end):
    period = Period(granularity, day)
    assert (period.start, period.end) == (start, end)


def test_constructors():
    assert Period.iso_week(2026, 46) == Period(Granularity.WEEK, date(2026, 11, 9))
    assert Period.iso_week(2026, 1).start == date(2025, 12, 29)
    assert Period.month(2026, 11).end == date(2026, 11, 30)
    assert Period.quarter(2027, 1).end == date(2027, 3, 31)


def test_status():
    week = Period.iso_week(2026, 46)
    assert week.status(date(2026, 11, 8)) is PeriodStatus.UPCOMING
    assert week.status(date(2026, 11, 15)) is PeriodStatus.CURRENT
    assert week.status(date(2026, 11, 16)) is PeriodStatus.OVERDUE


def test_shift():
    assert Period.month(2026, 11).shift(1) == Period.month(2026, 12)
    assert Period.month(2026, 12).shift(1) == Period.month(2027, 1)
    # 2026 has 53 ISO weeks.
    assert Period.iso_week(2026, 52).shift(2) == Period.iso_week(2027, 1)
    assert Period.day(date(2026, 1, 31)).shift(1, Granularity.MONTH) == Period.day(date(2026, 2, 28))
    # A week task repeating monthly lands in the week containing the same day next month.
    assert Period.iso_week(2026, 46).shift(1, Granularity.MONTH).start == date(2026, 12, 7)


@pytest.mark.parametrize(
    ("period", "lang", "label"),
    [
        (Period.iso_week(2026, 46), "de", "KW 46"),
        (Period.iso_week(2027, 2), "de", "KW 2 2027"),
        (Period.iso_week(2026, 46), "en", "Week 46"),
        (Period.month(2026, 3), "de", "März"),
        (Period.quarter(2026, 4), "de", "Q4"),
        (Period.year(2027), "de", "2027"),
        (Period.day(date(2026, 11, 9)), "de", "Mo, 9. Nov."),
        (Period.day(date(2026, 11, 9)), "en-GB", "Mon, Nov 9"),
    ],
)
def test_label(period, lang, label):
    assert period.label(lang, today=date(2026, 10, 31)) == label


def test_serialization_roundtrip():
    period = Period.quarter(2026, 4)
    assert Period.from_dict(period.as_dict()) == period
    # Any day inside the period is accepted and normalized.
    assert Period.from_dict({"granularity": "month", "start": "2026-11-17"}) == Period.month(2026, 11)
