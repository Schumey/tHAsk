"""Quick entry: take due period, time, recurrence and priority out of a typed task title.

"Reifen wechseln nächsten Monat !" -> title "Reifen wechseln", due November, low priority (! = low, !! = medium, !!! = high).
German first, with the most common English, Dutch, French and Spanish phrases.
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
# Short names are only understood in recurrences ("jeden Mi und Sa"), alone they are too ambiguous.
_WEEKDAYS_SHORT = [
    ("mo", "mon"),
    ("di", "tue", "tues"),
    ("mi", "wed"),
    ("do", "thu", "thur", "thurs"),
    ("fr", "fri"),
    ("sa", "sat"),
    ("so", "sun"),
]
_REC_DAY = "(?:" + _WEEKDAY + "|(?:" + "|".join(name for names in _WEEKDAYS_SHORT for name in names) + r")\.?)"
_REC_DAYS_ADVERB = "|".join(f"{names[0]}s" for names in _WEEKDAYS)
_DAY_SEP = r"(?:\s*[,/&+]\s*|\s+(?:und|and|u\.)\s+)"
_EVERY = r"(?:jede[nrs]?|every)"
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
_NUMBER_WORDS = {
    "ein": 1, "eine": 1, "einen": 1, "einer": 1, "einem": 1, "zwei": 2, "drei": 3, "vier": 4,
    "a": 1, "one": 1, "two": 2, "other": 2, "three": 3, "four": 4,
}


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
    word = word.lower().rstrip(".")
    for table in (_WEEKDAYS, _WEEKDAYS_SHORT):
        for index, names in enumerate(table):
            if word in names or (word.endswith("s") and word[:-1] in names):
                return index
    raise ValueError(word)


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


def _weekly_on(days: list[int], interval: int, today: date) -> dict[str, Any]:
    """A weekly recurrence on the given weekdays; one weekday needs no list, the due day says it."""
    recurrence = Recurrence(Granularity.WEEK, max(1, interval), tuple(days) if len(set(days)) > 1 else ())
    first = min(_next_weekday(today, day, include_today=True) for day in days)
    return {"recurrence": recurrence, "due": Period.day(first)}


def _recurring_weekdays(match: re.Match[str], today: date) -> dict[str, Any]:
    days = [_weekday_index(day[0]) for day in _REC_DAY_PATTERN.finditer(match["days"])]
    return _weekly_on(days, _number(match["n"]) if match["n"] else 1, today)


def _recurring_workdays(match: re.Match[str], today: date) -> dict[str, Any]:
    weekend = re.search("wochenend|weekend", match[0], re.IGNORECASE)
    return _weekly_on([5, 6] if weekend else [0, 1, 2, 3, 4], 1, today)


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


_REC_DAY_PATTERN = re.compile(rf"{_B}(?:{_REC_DAYS_ADVERB}|{_REC_DAY}){_E}", re.IGNORECASE)

_RULES = [
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:alle|every)\s+(?P<n>\d+|zwei|drei|vier|two|three|four|other)\s+(?:wochen|weeks?)\s+(?:(?:am|an|on)\s+)?"
        rf"(?P<days>{_REC_DAY}(?:{_DAY_SEP}{_REC_DAY})*){_E}",
        _recurring_weekdays,
    ),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}{_EVERY}\s+(?P<n>)(?P<days>{_REC_DAY}(?:{_DAY_SEP}(?:{_EVERY}\s+)?{_REC_DAY})*){_E}",
        _recurring_weekdays,
    ),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:werktags|wochentags|(?:an\s+)?werktagen|jeden\s+werktag|every\s+weekday|weekdays"
        rf"|jedes\s+wochenende|wochenends|every\s+weekend)(?![\w-])",
        _recurring_workdays,
    ),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:immer\s+)?(?P<n>)(?P<days>(?:{_REC_DAYS_ADVERB})(?:{_DAY_SEP}(?:{_REC_DAYS_ADVERB}))*)(?![\w-])",
        _recurring_weekdays,
    ),
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


# -- Dutch, French and Spanish -------------------------------------------------------------------------------
# The most common phrases; German and English above stay the reference. Words map to units explicitly, since the
# first-letter rule of _unit() does not fit these languages ("jour" is a day, "jaar" a year).

_X_UNITS = {
    Granularity.DAY: ("dag", "dagen", "jour", "jours", "día", "dia", "días", "dias"),
    Granularity.WEEK: ("week", "weken", "semaine", "semaines", "semana", "semanas"),
    Granularity.MONTH: ("maand", "maanden", "mois", "mes", "meses"),
    Granularity.QUARTER: ("kwartaal", "kwartalen", "trimestre", "trimestres"),
    Granularity.YEAR: ("jaar", "jaren", "an", "ans", "année", "annee", "années", "annees", "año", "ano", "años", "anos"),
}
_X_UNIT = "|".join(sorted((word for words in _X_UNITS.values() for word in words), key=len, reverse=True))
_X_WEEKDAYS = [
    ("maandag", "lundi", "lunes"),
    ("dinsdag", "mardi", "martes"),
    ("woensdag", "mercredi", "miércoles", "miercoles"),
    ("donderdag", "jeudi", "jueves"),
    ("vrijdag", "vendredi", "viernes"),
    ("zaterdag", "samedi", "sábado", "sabado"),
    ("zondag", "dimanche", "domingo"),
]
_X_WEEKDAY = "|".join(name for names in _X_WEEKDAYS for name in names)
# Plural forms for recurrences ("tous les lundis", "todos los lunes", "maandags").
_X_REC_DAY = r"(?:" + _X_WEEKDAY + "|" + "|".join(f"{names[0]}s|{names[1]}s" for names in _X_WEEKDAYS) + ")"
_X_MONTHS = [
    ("januari", "janvier", "enero"),
    ("februari", "février", "fevrier", "febrero"),
    ("maart", "marzo"),
    ("april", "avril", "abril"),
    ("mei", "mayo"),
    ("juni", "juin", "junio"),
    ("juli", "juillet", "julio"),
    ("augustus", "août", "aout", "agosto"),
    ("september", "septembre", "septiembre", "setiembre"),
    ("oktober", "octobre", "octubre"),
    ("november", "novembre", "noviembre"),
    ("december", "décembre", "decembre", "diciembre"),
]
# "mars" (also the planet) and "mayo" only count after a preposition.
_X_MONTH = "|".join(name for names in _X_MONTHS for name in names if name != "mayo")
_X_PREP = (
    r"(?:(?:op|voor|tegen|uiterlijk|in|le|pour|d'ici|avant|en|au|el|para|antes\s+del?|hasta\s+el)\s+)?"
)
_X_MONTH_PREP = r"(?:in|en|au\s+mois\s+de|d'ici|avant|pour|para|antes\s+de|hasta)\s+"
_X_NEXT = r"(?:volgende|komende|prochaine?|próxim[oa]|proxim[oa])"
_X_THIS = r"(?:deze|dit|cette|cet|ce|esta|este)"
_X_EVERY = r"(?:elke|iedere|chaque|tous\s+les|toutes\s+les|cada|todos\s+los|todas\s+las)"
_X_AND = r"(?:\s*[,/&+]\s*|\s+(?:en|et|y|e)\s+)"
_X_NUMBER_WORDS = {"een": 1, "un": 1, "une": 1, "una": 1, "uno": 1, "twee": 2, "deux": 2, "dos": 2, "drie": 3, "trois": 3, "tres": 3}
_X_NUMBER = r"(?:\d+|" + "|".join(_X_NUMBER_WORDS) + ")"
_X_REC_DAY_PATTERN = re.compile(rf"{_B}{_X_REC_DAY}{_E}", re.IGNORECASE)


def _x_unit(word: str) -> Granularity:
    word = word.lower()
    return next(unit for unit, words in _X_UNITS.items() if word in words)


def _x_number(word: str) -> int:
    return int(word) if word.isdigit() else _X_NUMBER_WORDS[word.lower()]


def _x_weekday_index(word: str) -> int:
    word = word.lower()
    for index, names in enumerate(_X_WEEKDAYS):
        if word in names or (word.endswith("s") and word[:-1] in names):
            return index
    raise ValueError(word)


def _x_month_index(word: str) -> int:
    word = word.lower()
    if word == "mars":
        return 3
    return next(index + 1 for index, names in enumerate(_X_MONTHS) if word in names)


def _x_relative_day(match: re.Match[str], today: date) -> dict[str, Any]:
    word = re.sub(r"\s+", " ", match[1].lower())
    offset = {"vandaag": 0, "aujourd'hui": 0, "hoy": 0, "demain": 1, "mañana": 1, "manana": 1}.get(word, 2)
    return {"due": Period.day(today + timedelta(days=offset))}


def _x_period(match: re.Match[str], today: date) -> dict[str, Any]:
    """"volgende week", "la semaine prochaine", "el próximo mes", "este año"."""
    return {"due": Period(_x_unit(match["unit"]), today).shift(1 if match["next"] else 0)}


def _x_in_n(match: re.Match[str], today: date) -> dict[str, Any]:
    count, unit = _x_number(match[1]), _x_unit(match[2])
    match unit:
        case Granularity.DAY:
            return {"due": Period.day(today + timedelta(days=count))}
        case Granularity.WEEK:
            return {"due": Period(unit, today + timedelta(weeks=count))}
        case Granularity.MONTH:
            return {"due": Period(unit, add_months(today, count))}
        case Granularity.QUARTER:
            return {"due": Period(unit, add_months(today, 3 * count))}
    return {"due": Period(Granularity.YEAR, add_months(today, 12 * count))}


def _x_end_of(match: re.Match[str], today: date) -> dict[str, Any]:
    return {"due": Period(_x_unit(match["unit"]), today).shift(1 if match["next"] else 0)}


def _x_weekday(match: re.Match[str], today: date) -> dict[str, Any]:
    return {"due": Period.day(_next_weekday(today, _x_weekday_index(match[1]), include_today=False))}


def _x_month(match: re.Match[str], today: date) -> dict[str, Any]:
    month = _x_month_index(match[1])
    year = int(match[2]) if match[2] else today.year + (month < today.month)
    return {"due": Period.month(year, month)}


def _x_recurring_weekdays(match: re.Match[str], today: date) -> dict[str, Any]:
    days = [_x_weekday_index(day[0]) for day in _X_REC_DAY_PATTERN.finditer(match["days"])]
    return _weekly_on(days, 1, today)


def _x_recurring_unit(match: re.Match[str], today: date) -> dict[str, Any]:
    word = (match["unit"] or match["adverb"]).lower()
    if match["adverb"]:
        unit = next(
            unit
            for unit, stems in (
                (Granularity.DAY, ("dage", "quotid", "diari")),
                (Granularity.WEEK, ("weke", "hebdo", "seman")),
                (Granularity.MONTH, ("maand", "mensu")),
                (Granularity.YEAR, ("jaar", "annu", "anua")),
            )
            if word.startswith(stems)
        )
    else:
        unit = _x_unit(word)
    return {"recurrence": Recurrence(unit), "default_due": Period(unit, today)}


def _x_recurring_every_n(match: re.Match[str], today: date) -> dict[str, Any]:
    unit = _x_unit(match[2])
    return {"recurrence": Recurrence(unit, max(1, int(match[1]))), "default_due": Period(unit, today)}


def _x_time(match: re.Match[str], today: date) -> dict[str, Any] | None:
    hour, minute = int(match["hour"]), int(match["minute"] or 0)
    if hour > 23 or minute > 59:
        return None
    return {"due_time": f"{hour:02d}:{minute:02d}"}


# Weekdays as a recurrence need "every" (or a plural): "elke maandag", "chaque lundi", "tous les lundis", "cada lunes".
_X_RECURRENCE_RULES = [
    _rule(
        KIND_RECURRENCE,
        rf"{_B}{_X_EVERY}\s+(?P<days>{_X_REC_DAY}(?:{_X_AND}(?:{_X_EVERY}\s+)?{_X_REC_DAY})*){_E}",
        _x_recurring_weekdays,
    ),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:om\s+de|tous\s+les|toutes\s+les|cada)\s+(\d+)\s+({_X_UNIT}){_E}",
        _x_recurring_every_n,
    ),
    _rule(
        KIND_RECURRENCE,
        rf"{_B}(?:{_X_EVERY}\s+(?P<unit>{_X_UNIT})"
        rf"|(?P<adverb>dagelijks|wekelijks|maandelijks|jaarlijks|quotidiennement|quotidien(?:ne)?|hebdomadaire"
        rf"|mensuel(?:le)?|annuel(?:le)?|diariamente|diario|semanal(?:mente)?|mensual(?:mente)?|anual(?:mente)?)){_E}",
        _x_recurring_unit,
    ),
]
_X_TIME_RULES = [
    # "om 9 uur", "om 9:30", "à 9h", "9h30", "à 9:30", "a las 9", "a las 9:30".
    _rule(KIND_TIME, rf"{_B}(?:om\s+)?(?P<hour>\d{{1,2}})(?::(?P<minute>\d{{2}}))?\s*uur{_E}", _x_time),
    _rule(KIND_TIME, rf"{_B}om\s+(?P<hour>\d{{1,2}}):(?P<minute>\d{{2}}){_E}", _x_time),
    # "9h" alone could be a duration ("2h lernen"); without "à" only with minutes.
    _rule(KIND_TIME, rf"{_B}à\s+(?P<hour>\d{{1,2}})\s*h(?:\s*(?P<minute>\d{{2}}))?{_E}", _x_time),
    _rule(KIND_TIME, rf"{_B}(?P<hour>\d{{1,2}})h(?P<minute>\d{{2}}){_E}", _x_time),
    _rule(KIND_TIME, rf"{_B}à\s+(?P<hour>\d{{1,2}}):(?P<minute>\d{{2}}){_E}", _x_time),
    _rule(KIND_TIME, rf"{_B}a\s+las?\s+(?P<hour>\d{{1,2}})(?::(?P<minute>\d{{2}}))?{_E}", _x_time),
]
_X_DUE_RULES = [
    _rule(
        KIND_DUE,
        rf"{_B}(?:over|binnen|dans|en|dentro\s+de)\s+({_X_NUMBER})\s+({_X_UNIT}){_E}",
        _x_in_n,
    ),
    _rule(
        KIND_DUE,
        rf"{_B}(?:pour\s+|para\s+)?(vandaag|aujourd'hui|hoy|overmorgen|après-demain|apres-demain|demain"
        rf"|pasado\s+mañana|pasado\s+manana|mañana|manana){_E}",
        _x_relative_day,
    ),
    _rule(
        KIND_DUE,
        rf"{_B}(?:eind(?:e)?\s+(?:van\s+)?(?:de\s+|het\s+)?(?P<next>volgende\s+)?(?:deze\s+|dit\s+)?(?P<unit>week|maand|kwartaal|jaar)"
        rf"|fin\s+(?:de\s+la\s+|du\s+|de\s+l'|d')(?P<unit2>semaine|mois|trimestre|année|annee)(?P<next2>\s+prochaine?)?"
        rf"|(?:a\s+)?finales?\s+de(?:l|\s+la)?\s+(?P<unit3>semana|mes|trimestre|año|ano)(?P<next3>\s+que\s+viene)?){_E}",
        lambda match, today: _x_end_of(_XEndMatch(match), today),
    ),
    _rule(
        KIND_DUE,
        rf"{_B}{_X_PREP}(?:(?:la|le|l'|el)\s*)?(?P<next>{_X_NEXT})\s+(?P<unit>{_X_UNIT}){_E}",
        _x_period,
    ),
    _rule(
        KIND_DUE,
        rf"{_B}{_X_PREP}(?:(?:la|le|l'|el)\s*)?(?P<unit>semaine|mois|trimestre|année|annee|an|semana|mes|trimestre|año|ano)"
        rf"\s+(?P<next>prochaine?|que\s+viene|próxim[oa]|proxim[oa]){_E}",
        _x_period,
    ),
    _rule(KIND_DUE, rf"{_B}{_X_PREP}(?P<next>){_X_THIS}\s+(?P<unit>{_X_UNIT}){_E}", _x_period),
    _rule(
        KIND_DUE,
        rf"{_B}{_X_PREP}(?:la\s+|en\s+la\s+)?(?:semaine|semana|sem\.?)\s*(\d{{1,2}})(?:\s*[/.]?\s*(\d{{4}}))?{_E}",
        _calendar_week,
    ),
    _rule(
        KIND_DUE,
        rf"{_B}{_X_PREP}(?:(?:volgende|komende|el\s+próximo|el\s+proximo|el)\s+)?({_X_WEEKDAY})(?:\s+prochain)?{_E}",
        _x_weekday,
    ),
    _rule(KIND_DUE, rf"{_B}{_X_PREP}({_X_MONTH})(?:\s+(?:de\s+)?(\d{{4}}))?{_E}", _x_month),
    _rule(KIND_DUE, rf"{_B}{_X_MONTH_PREP}(mars|mayo)(?:\s+(?:de\s+)?(\d{{4}}))?{_E}", _x_month),
]


class _XEndMatch:
    def __init__(self, match: re.Match[str]) -> None:
        self._match = match

    def __getitem__(self, key: str) -> str | None:
        m = self._match
        if key == "unit":
            return m["unit"] or m["unit2"] or m["unit3"]
        if key == "next":
            return m["next"] or m["next2"] or m["next3"]
        return m[key]


# Recurrences and times go before the German/English time rule, so "om 9:30" does not leave "om" in the title.
_first_time = next(index for index, (kind, _, _) in enumerate(_RULES) if kind == KIND_TIME)
_RULES[_first_time:_first_time] = _X_RECURRENCE_RULES + _X_TIME_RULES
_RULES.extend(_X_DUE_RULES)


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
