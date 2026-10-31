"""Quick entry: take due period, time, recurrence and priority out of a typed task title.

"Reifen wechseln nächsten Monat !" -> title "Reifen wechseln", due November, low priority (! = low, !! = medium, !!! = high).
German first, with the most common English phrases.
"""

from __future__ import annotations

from collections.abc import Callable, Container
from dataclasses import dataclass, field
from datetime import date, timedelta
import re
from typing import Any

from .models import Recurrence
from .period import Granularity, Period, add_months

KIND_DUE = "due"
KIND_TIME = "time"
KIND_RECURRENCE = "recurrence"
KIND_PRIORITY = "priority"

_B = r"(?<!\w)"
_E = r"(?!\w)"
_AE = "(?:ä|ae)"
_OE = "(?:ö|oe)"
_UE = "(?:ü|ue)"
_PREP = (
    r"(?:(?:bis\s+(?:zum\s+|zur\s+)?|am\s+|im\s+|in\s+der\s+|in\s+|f" + _UE + r"r\s+|"
    r"f" + _AE + r"llig\s+(?:am\s+|im\s+|in\s+(?:der\s+)?|bis\s+)?|by\s+|on\s+)?)"
)
# A preposition is required where the word alone would be too ambiguous ("bis Nov.", "bis 2027").
_PREP_REQUIRED = r"(?:(?:bis|im|in|ab|f" + _UE + r"r|by)\s+)"
_THIS = r"(?:diese[nrsm]?|this)"
_NEXT = r"(?:n" + _AE + r"chste[nrsm]?|kommende[nrsm]?|next)"
_AFTER_NEXT = r"(?:" + _UE + r"bern" + _AE + r"chste[nrsm]?)"

_WEEKDAYS = [
    ("montag", "monday"),
    ("dienstag", "tuesday"),
    ("mittwoch", "wednesday"),
    ("donnerstag", "thursday"),
    ("freitag", "friday"),
    ("samstag", "saturday"),
    ("sonntag", "sunday"),
]
_WEEKDAY = "|".join(name for names in _WEEKDAYS for name in names)
_MONTHS = [
    ("januar", "jan"),
    ("februar", "feb"),
    ("m" + _AE + "rz", "m" + _AE + "r|mrz"),
    ("april", "apr"),
    ("mai", "mai"),
    ("juni", "jun"),
    ("juli", "jul"),
    ("august", "aug"),
    ("september", "sept|sep"),
    ("oktober", "okt"),
    ("november", "nov"),
    ("dezember", "dez"),
]
_MONTH_FULL = "|".join(full for full, _ in _MONTHS)
_MONTH_SHORT = "|".join(short for _, short in _MONTHS)
_NUMBER_WORDS = {"ein": 1, "eine": 1, "einen": 1, "einer": 1, "einem": 1, "zwei": 2, "drei": 3, "vier": 4, "a": 1, "one": 1, "two": 2, "three": 3}


@dataclass(slots=True)
class Token:
    kind: str
    start: int
    end: int
    text: str


@dataclass(slots=True)
class ParseResult:
    title: str
    due: Period | None = None
    due_time: str | None = None
    recurrence: Recurrence | None = None
    priority: int = 0
    tokens: list[Token] = field(default_factory=list)

    def as_dict(self, lang: str, today: date) -> dict[str, Any]:
        return {
            "title": self.title,
            "due": self.due.as_dict() if self.due else None,
            "due_label": self.due.label(lang, today) if self.due else None,
            "due_time": self.due_time,
            "recurrence": self.recurrence.as_dict() if self.recurrence else None,
            "priority": self.priority,
            "tokens": [
                {"kind": token.kind, "start": token.start, "end": token.end, "text": token.text}
                for token in self.tokens
            ],
        }


def _unit(word: str) -> Granularity:
    word = word.lower()
    if word.startswith(("viertel", "quartal", "quarter", "q")):
        return Granularity.QUARTER
    if word.startswith(("t", "d")):
        return Granularity.DAY
    if word.startswith("w"):
        return Granularity.WEEK
    if word.startswith("m"):
        return Granularity.MONTH
    return Granularity.YEAR


def _number(word: str) -> int:
    return int(word) if word.isdigit() else _NUMBER_WORDS[word.lower()]


def _weekday_index(word: str) -> int:
    word = word.lower()
    return next(index for index, names in enumerate(_WEEKDAYS) if word in names)


def _month_index(word: str) -> int:
    word = word.lower().rstrip(".")
    for index, (full, short) in enumerate(_MONTHS):
        if re.fullmatch(f"{full}|{short}", word):
            return index + 1
    raise ValueError(word)


def _next_weekday(today: date, weekday: int, include_today: bool) -> date:
    days = (weekday - today.weekday()) % 7
    if days == 0 and not include_today:
        days = 7
    return today + timedelta(days=days)


def _year_for(month: int, day: int, today: date) -> int:
    """A date without a year means the next such date, never one in the past."""
    return today.year + ((month, day) < (today.month, today.day))


# Each handler gets the match and today and returns the fields it sets, or None if it does not apply.
type Handler = Callable[[re.Match[str], date], dict[str, Any] | None]


def _recurring_weekday(match: re.Match[str], today: date) -> dict[str, Any]:
    day = _next_weekday(today, _weekday_index(match[1]), include_today=True)
    return {"recurrence": Recurrence(Granularity.WEEK), "due": Period.day(day)}


def _recurring_every_n(match: re.Match[str], today: date) -> dict[str, Any]:
    unit = _unit(match[2])
    return {"recurrence": Recurrence(unit, max(1, int(match[1]))), "default_due": Period(unit, today)}


def _recurring_unit(match: re.Match[str], today: date) -> dict[str, Any]:
    unit = _unit(next(group for group in match.groups() if group))
    return {"recurrence": Recurrence(unit), "default_due": Period(unit, today)}


def _time(match: re.Match[str], today: date) -> dict[str, Any] | None:
    hour, minute = int(match["hour"]), int(match["minute"] or 0)
    if hour > 23 or minute > 59:
        return None
    return {"due_time": f"{hour:02d}:{minute:02d}"}


def _in_n(match: re.Match[str], today: date) -> dict[str, Any]:
    count, unit = _number(match[1]), _unit(match[2])
    match unit:
        case Granularity.DAY:
            return {"due": Period.day(today + timedelta(days=count))}
        case Granularity.WEEK:
            return {"due": Period(unit, today + timedelta(weeks=count))}
        case Granularity.MONTH:
            return {"due": Period(unit, add_months(today, count))}
    return {"due": Period(Granularity.YEAR, add_months(today, 12 * count))}


def _relative_day(match: re.Match[str], today: date) -> dict[str, Any]:
    word = match[1].lower()
    offset = 0 if word in ("heute", "today") else 1 if word in ("morgen", "tomorrow") else 2
    return {"due": Period.day(today + timedelta(days=offset))}


def _relative_period(match: re.Match[str], today: date) -> dict[str, Any]:
    which = match[1].lower()
    offset = 2 if re.match(_AFTER_NEXT, which) else 1 if re.match(_NEXT, which) else 0
    return {"due": Period(_unit(match[2]), today).shift(offset)}


def _end_of(match: re.Match[str], today: date) -> dict[str, Any]:
    unit = _unit(match["unit"] or match["unit2"])
    return {"due": Period(unit, today).shift(1 if match["next"] else 0)}


def _calendar_week(match: re.Match[str], today: date) -> dict[str, Any] | None:
    week = int(match[1])
    if match[2]:
        year = int(match[2])
    else:
        year = today.isocalendar().year
        if week < today.isocalendar().week:
            year += 1
    try:
        return {"due": Period.iso_week(year, week)}
    except ValueError:
        return None


def _quarter(match: re.Match[str], today: date) -> dict[str, Any]:
    quarter = int(match[1])
    year = int(match[2]) if match[2] else today.year + (quarter < (today.month - 1) // 3 + 1)
    return {"due": Period.quarter(year, quarter)}


def _numeric_date(match: re.Match[str], today: date) -> dict[str, Any] | None:
    day, month = int(match[1]), int(match[2])
    if match[3]:
        year = int(match[3]) + (2000 if len(match[3]) == 2 else 0)
    else:
        year = _year_for(month, day, today)
    try:
        return {"due": Period.day(date(year, month, day))}
    except ValueError:
        return None


def _iso_date(match: re.Match[str], today: date) -> dict[str, Any] | None:
    try:
        return {"due": Period.day(date.fromisoformat(match[1]))}
    except ValueError:
        return None


def _weekday(match: re.Match[str], today: date) -> dict[str, Any]:
    return {"due": Period.day(_next_weekday(today, _weekday_index(match[1]), include_today=False))}


def _month(match: re.Match[str], today: date) -> dict[str, Any]:
    month = _month_index(match[1])
    year = int(match[2]) if match[2] else today.year + (month < today.month)
    return {"due": Period.month(year, month)}


def _year(match: re.Match[str], today: date) -> dict[str, Any]:
    return {"due": Period.year(int(match[1]))}


def _priority(match: re.Match[str], today: date) -> dict[str, Any]:
    return {"priority": min(len(match[0].strip()), 3)}


def _rule(kind: str, pattern: str, handler: Handler) -> tuple[str, re.Pattern[str], Handler]:
    return kind, re.compile(pattern, re.IGNORECASE), handler


_RULES = [
    _rule(KIND_RECURRENCE, rf"{_B}(?:jede[nrs]?|every)\s+({_WEEKDAY}){_E}", _recurring_weekday),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:alle|every)\s+(\d+)\s+(tage|wochen|monate|quartale|jahre|days|weeks|months|quarters|years){_E}",
        _recurring_every_n,
    ),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:(?:jede[nrs]?|every)\s+(tag|woche|monat|quartal|jahr|day|week|month|quarter|year)"
        rf"|(t{_AE}glich|w{_OE}chentlich|monatlich|viertelj{_AE}hrlich|quartalsweise|j{_AE}hrlich"
        rf"|daily|weekly|monthly|quarterly|yearly)){_E}",
        _recurring_unit,
    ),
    _rule(
        KIND_TIME,
        rf"{_B}(?:um\s+|at\s+)?(?P<hour>\d{{1,2}})(?::(?P<minute>\d{{2}})(?:\s*uhr)?|(?:\.(?P<minute2>\d{{2}}))?\s*uhr)(?!\w)",
        lambda match, today: _time(_TimeMatch(match), today),
    ),
    _rule(
        KIND_DUE,
        rf"{_B}in\s+(\d+|eine[mnr]?|ein|zwei|drei|vier|a|one|two|three)\s+"
        rf"(tag(?:en)?|wochen?|monat(?:en)?|jahr(?:en)?|days?|weeks?|months?|years?){_E}",
        _in_n,
    ),
    _rule(KIND_DUE, rf"{_B}{_PREP}(heute|today|morgen|tomorrow|{_UE}bermorgen){_E}", _relative_day),
    _rule(
        KIND_DUE,
        rf"{_B}{_PREP}(?:ende\s+(?:(?:des|der)\s+)?(?P<next>{_NEXT}\s+)?(?:diese[sr]\s+)?(?P<unit>woche|monats|quartals|jahres)"
        rf"|(?P<unit2>monats|quartals|jahres)ende|end\s+of\s+(?:the\s+)?(?P<unit3>week|month|quarter|year)){_E}",
        lambda match, today: _end_of(_EndMatch(match), today),
    ),
    _rule(
        KIND_DUE,
        rf"{_B}{_PREP}(?:(?:der|den|dem|das)\s+)?({_AFTER_NEXT}|{_THIS}|{_NEXT})\s+"
        rf"(woche|monats?|quartals?|jahr(?:es)?|week|month|quarter|year){_E}",
        _relative_period,
    ),
    _rule(KIND_DUE, rf"{_B}{_PREP}(?:der\s+)?(?:kw|kalenderwoche|woche|week|wk)\s*(\d{{1,2}})(?:\s*[/.]?\s*(\d{{4}}))?{_E}", _calendar_week),
    _rule(KIND_DUE, rf"{_B}{_PREP}(?:im\s+)?(?:q|quartal\s*)([1-4])(?:\s*[/.]?\s*(\d{{4}}))?{_E}", _quarter),
    _rule(KIND_DUE, rf"{_B}{_PREP}(\d{{4}}-\d{{2}}-\d{{2}}){_E}", _iso_date),
    _rule(KIND_DUE, rf"{_B}{_PREP}(\d{{1,2}})\.(\d{{1,2}})\.(\d{{4}}|\d{{2}})?(?!\d)", _numeric_date),
    _rule(KIND_DUE, rf"{_B}{_PREP}(?:{_NEXT}\s+)?({_WEEKDAY}){_E}", _weekday),
    _rule(KIND_DUE, rf"{_B}{_PREP}({_MONTH_FULL})(?:\s+(\d{{4}}))?{_E}", _month),
    _rule(KIND_DUE, rf"{_B}{_PREP_REQUIRED}({_MONTH_SHORT})\.?(?:\s+(\d{{4}}))?(?!\w)", _month),
    _rule(KIND_DUE, rf"{_B}(?:{_PREP_REQUIRED}|im\s+jahr\s+|jahr\s+)(\d{{4}}){_E}", _year),
    _rule(KIND_PRIORITY, r"(?<!\S)!+(?!\S)", _priority),
]


class _TimeMatch:
    """Merges the two minute groups of the time pattern."""

    def __init__(self, match: re.Match[str]) -> None:
        self._match = match

    def __getitem__(self, key: str) -> str | None:
        if key == "minute":
            return self._match["minute"] or self._match["minute2"]
        return self._match[key]


class _EndMatch(_TimeMatch):
    def __getitem__(self, key: str) -> str | None:
        if key == "unit":
            return self._match["unit"] or self._match["unit3"]
        return self._match[key]


def parse(text: str, today: date, disabled: Container[str] = ()) -> ParseResult:
    """Extract structured data from a task title. Kinds in `disabled` are left in the title."""
    fields: dict[str, Any] = {}
    tokens: list[Token] = []

    def free(start: int, end: int) -> bool:
        return all(end <= token.start or start >= token.end for token in tokens)

    for kind, pattern, handler in _RULES:
        if kind in disabled or (kind == KIND_DUE and "due" in fields) or (kind in fields):
            continue
        for match in pattern.finditer(text):
            if not free(match.start(), match.end()):
                continue
            values = handler(match, today)
            if values is None:
                continue
            fields.update(values)
            if kind == KIND_RECURRENCE:
                fields[KIND_RECURRENCE] = values["recurrence"]
            tokens.append(Token(kind, match.start(), match.end(), match[0].strip()))
            break

    due: Period | None = fields.get("due") or fields.get("default_due")
    due_time = fields.get("due_time")
    if due_time and due is None:
        due = Period.day(today)
    if due_time and due.granularity is not Granularity.DAY:
        # "KW 47 um 9 Uhr" makes no sense; keep the time in the title instead.
        tokens = [token for token in tokens if token.kind != KIND_TIME]
        due_time = None

    title = text
    for token in sorted(tokens, key=lambda token: token.start, reverse=True):
        title = title[: token.start] + " " + title[token.end :]
    title = re.sub(r"\s+", " ", title).strip(" ,;:-–")
    tokens.sort(key=lambda token: token.start)
    return ParseResult(
        title=title,
        due=due,
        due_time=due_time,
        recurrence=fields.get("recurrence"),
        priority=fields.get("priority", 0),
        tokens=tokens,
    )
