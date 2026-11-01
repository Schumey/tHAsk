"""Fuzzy due dates: a task is due on a day, or somewhere in a week, month, quarter or year."""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date, timedelta
from enum import StrEnum
from typing import Any


class Granularity(StrEnum):
    """How precise a due period is."""

    DAY = "day"
    WEEK = "week"
    MONTH = "month"
    QUARTER = "quarter"
    YEAR = "year"


class PeriodStatus(StrEnum):
    """Where a period lies relative to a given day."""

    OVERDUE = "overdue"
    CURRENT = "current"
    UPCOMING = "upcoming"


LANGUAGES = ("de", "en", "nl", "fr", "es")


def language(lang: str | None) -> str:
    """The supported language for a Home Assistant language code ("de-CH" -> "de"); English otherwise."""
    code = (lang or "en").split("-")[0].lower()
    return code if code in LANGUAGES else "en"


_MONTHS = {
    "de": [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember",
    ],
    "en": [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ],
    "nl": [
        "januari", "februari", "maart", "april", "mei", "juni",
        "juli", "augustus", "september", "oktober", "november", "december",
    ],
    "fr": [
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre",
    ],
    "es": [
        "enero", "febrero", "marzo", "abril", "mayo", "junio",
        "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
    ],
}
_MONTHS_SHORT = {
    "de": ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
    "en": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
    "nl": ["jan.", "feb.", "mrt.", "apr.", "mei", "jun.", "jul.", "aug.", "sep.", "okt.", "nov.", "dec."],
    "fr": ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."],
    "es": ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic"],
}
_WEEKDAYS_SHORT = {
    "de": ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"],
    "en": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    "nl": ["ma", "di", "wo", "do", "vr", "za", "zo"],
    "fr": ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."],
    "es": ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"],
}
# Day label ("Mo, 5. Nov.") and calendar week label per language.
_DAY_FORMAT = {
    "de": "{weekday}, {day}. {month}",
    "en": "{weekday}, {month} {day}",
    "nl": "{weekday} {day} {month}",
    "fr": "{weekday} {day} {month}",
    "es": "{weekday}, {day} {month}",
}
_WEEK_FORMAT = {"de": "KW {week}", "en": "Week {week}", "nl": "Week {week}", "fr": "Semaine {week}", "es": "Semana {week}"}


def add_months(day: date, months: int) -> date:
    """Add months to a date, clamping to the last day of the target month."""
    index = day.month - 1 + months
    year, month = day.year + index // 12, index % 12 + 1
    return date(year, month, min(day.day, calendar.monthrange(year, month)[1]))


def period_start(granularity: Granularity, day: date) -> date:
    """Return the first day of the period of the given granularity containing day."""
    match granularity:
        case Granularity.DAY:
            return day
        case Granularity.WEEK:
            return day - timedelta(days=day.weekday())
        case Granularity.MONTH:
            return day.replace(day=1)
        case Granularity.QUARTER:
            return date(day.year, 3 * ((day.month - 1) // 3) + 1, 1)
        case Granularity.YEAR:
            return date(day.year, 1, 1)


@dataclass(frozen=True, slots=True)
class Period:
    """A due period. Any date inside the period may be passed; it is normalized to its start."""

    granularity: Granularity
    start: date

    def __post_init__(self) -> None:
        granularity = Granularity(self.granularity)
        object.__setattr__(self, "granularity", granularity)
        object.__setattr__(self, "start", period_start(granularity, self.start))

    @classmethod
    def day(cls, day: date) -> Period:
        return cls(Granularity.DAY, day)

    @classmethod
    def iso_week(cls, year: int, week: int) -> Period:
        return cls(Granularity.WEEK, date.fromisocalendar(year, week, 1))

    @classmethod
    def month(cls, year: int, month: int) -> Period:
        return cls(Granularity.MONTH, date(year, month, 1))

    @classmethod
    def quarter(cls, year: int, quarter: int) -> Period:
        return cls(Granularity.QUARTER, date(year, 3 * (quarter - 1) + 1, 1))

    @classmethod
    def year(cls, year: int) -> Period:
        return cls(Granularity.YEAR, date(year, 1, 1))

    @property
    def end(self) -> date:
        """Last day of the period (inclusive)."""
        match self.granularity:
            case Granularity.DAY:
                return self.start
            case Granularity.WEEK:
                return self.start + timedelta(days=6)
            case Granularity.MONTH:
                return add_months(self.start, 1) - timedelta(days=1)
            case Granularity.QUARTER:
                return add_months(self.start, 3) - timedelta(days=1)
            case Granularity.YEAR:
                return date(self.start.year, 12, 31)

    def contains(self, day: date) -> bool:
        return self.start <= day <= self.end

    def overlaps(self, start: date, end: date) -> bool:
        return self.start <= end and start <= self.end

    def status(self, today: date) -> PeriodStatus:
        if self.end < today:
            return PeriodStatus.OVERDUE
        if self.start <= today:
            return PeriodStatus.CURRENT
        return PeriodStatus.UPCOMING

    def shift(self, count: int, unit: Granularity | None = None) -> Period:
        """Move the period by count units (default: its own granularity)."""
        match unit or self.granularity:
            case Granularity.DAY:
                start = self.start + timedelta(days=count)
            case Granularity.WEEK:
                start = self.start + timedelta(weeks=count)
            case Granularity.MONTH:
                start = add_months(self.start, count)
            case Granularity.QUARTER:
                start = add_months(self.start, 3 * count)
            case Granularity.YEAR:
                start = add_months(self.start, 12 * count)
        return Period(self.granularity, start)

    def label(self, lang: str = "de", today: date | None = None) -> str:
        """Human readable label, e.g. "KW 46", "November", "Q4 2026". The year is omitted when it is today's."""
        lang = language(lang)
        start = self.start
        match self.granularity:
            case Granularity.DAY:
                weekday = _WEEKDAYS_SHORT[lang][start.weekday()]
                month = _MONTHS_SHORT[lang][start.month - 1]
                text = _DAY_FORMAT[lang].format(weekday=weekday, day=start.day, month=month)
                year = start.year
            case Granularity.WEEK:
                year, week, _ = start.isocalendar()
                text = _WEEK_FORMAT[lang].format(week=week)
            case Granularity.MONTH:
                text, year = _MONTHS[lang][start.month - 1], start.year
            case Granularity.QUARTER:
                text, year = f"Q{(start.month - 1) // 3 + 1}", start.year
            case Granularity.YEAR:
                return str(start.year)
        if today is None or year != today.year:
            text = f"{text} {year}"
        return text

    def as_dict(self) -> dict[str, Any]:
        return {"granularity": self.granularity.value, "start": self.start.isoformat()}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Period:
        return cls(Granularity(data["granularity"]), date.fromisoformat(data["start"]))
