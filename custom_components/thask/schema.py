"""Voluptuous schemas shared by the WebSocket API and the services. Values come out in serialized form."""

from __future__ import annotations

from datetime import datetime

import voluptuous as vol

from homeassistant.helpers import config_validation as cv
from homeassistant.util import dt as dt_util

from .core.custom_periods import ANCHOR_PARTS, MAX_HORIZON_DAYS, MAX_OFFSET
from .core.models import PRIORITIES, TASK_SORTS
from .core.period import Granularity
from .core.triggers import CALENDAR_PARTS, CONDITION_KINDS, DUE_OPTIONS, MAX_DAYS_AHEAD

GRANULARITIES = [granularity.value for granularity in Granularity]
# Granularities a period has from a single date (not "custom", which needs an end and comes from a rule).
FIXED_GRANULARITIES = [granularity for granularity in GRANULARITIES if granularity != Granularity.CUSTOM]


def iso_date(value: object) -> str:
    return cv.date(value).isoformat()


def iso_datetime(value: object) -> str:
    parsed: datetime = cv.datetime(value)
    return dt_util.as_utc(parsed).isoformat()


def hh_mm(value: object) -> str:
    return cv.time(value).strftime("%H:%M")


PERIOD_SCHEMA = vol.Schema(
    {
        vol.Required("granularity"): vol.In(GRANULARITIES),
        vol.Required("start"): iso_date,
        # Only custom periods: last day, name and the rule that found them.
        vol.Optional("end"): vol.Any(None, iso_date),
        vol.Optional("name"): vol.Any(None, str),
        vol.Optional("rule"): vol.Any(None, str),
    }
)

RECURRENCE_SCHEMA = vol.Schema(
    {
        vol.Required("unit"): vol.In(GRANULARITIES),
        vol.Optional("interval", default=1): vol.All(vol.Coerce(int), vol.Range(min=1)),
        # Only for weekly recurrences: 0 = Monday … 6 = Sunday.
        vol.Optional("weekdays"): [vol.All(vol.Coerce(int), vol.Range(min=0, max=6))],
    }
)

STEP_SCHEMA = vol.Schema(
    {
        vol.Optional("id"): str,
        vol.Required("title"): str,
        vol.Optional("completed", default=False): bool,
    }
)

TASK_FIELDS = {
    vol.Optional("list_id"): str,
    vol.Optional("title"): vol.All(str, vol.Length(min=1)),
    vol.Optional("notes"): str,
    vol.Optional("completed"): bool,
    vol.Optional("priority"): vol.In(PRIORITIES),
    # Deprecated alias for priority 3 / 0, still sent by older clients.
    vol.Optional("important"): bool,
    vol.Optional("due"): vol.Any(None, PERIOD_SCHEMA),
    vol.Optional("due_time"): vol.Any(None, hh_mm),
    vol.Optional("reminder"): vol.Any(None, iso_datetime),
    vol.Optional("recurrence"): vol.Any(None, RECURRENCE_SCHEMA),
    vol.Optional("my_day"): vol.Any(None, iso_date),
    vol.Optional("steps"): [STEP_SCHEMA],
    vol.Optional("categories"): [str],
    vol.Optional("position"): vol.Coerce(float),
}

LIST_FIELDS = {
    vol.Optional("name"): vol.All(str, vol.Length(min=1)),
    vol.Optional("group"): vol.Any(None, str),
    vol.Optional("color"): vol.Any(None, str),
    vol.Optional("icon"): vol.Any(None, str),
    vol.Optional("position"): vol.Coerce(float),
    vol.Optional("sort"): vol.In((*TASK_SORTS, "important")),
    vol.Optional("members"): [str],
}


def _condition(value: dict) -> dict:
    """Each condition kind needs its own fields."""
    match value["kind"]:
        case "time":
            value["match"] = hh_mm(value.get("match", ""))
        case "calendar":
            if not value.get("entity", "").startswith("calendar."):
                raise vol.Invalid("A calendar condition needs a calendar entity")
        case _:
            if not value.get("entity"):
                raise vol.Invalid("A state condition needs an entity")
    return value


CONDITION_SCHEMA = vol.All(
    vol.Schema(
        {
            vol.Required("kind"): vol.In(CONDITION_KINDS),
            vol.Optional("entity", default=""): vol.All(str, vol.Strip),
            vol.Optional("match", default=""): vol.All(str, vol.Strip),
            vol.Optional("negate", default=False): bool,
            vol.Optional("hold_minutes", default=0): vol.All(vol.Coerce(int), vol.Range(min=0)),
            vol.Optional("part", default="any"): vol.In(CALENDAR_PARTS),
        }
    ),
    _condition,
)

TASK_TEMPLATE_SCHEMA = vol.Schema(
    {
        vol.Required("title"): vol.All(str, vol.Strip, vol.Length(min=1)),
        vol.Optional("list_id"): vol.Any(None, str),
        vol.Optional("due", default="day"): vol.In(DUE_OPTIONS),
        vol.Optional("priority", default=0): vol.In(PRIORITIES),
        vol.Optional("notes", default=""): str,
    }
)

TRIGGER_NAME = vol.All(str, vol.Strip, vol.Length(min=1))
TRIGGER_CONDITIONS = vol.All([CONDITION_SCHEMA], vol.Length(min=1))

TRIGGER_FIELDS = {
    vol.Optional("name"): TRIGGER_NAME,
    vol.Optional("conditions"): TRIGGER_CONDITIONS,
    vol.Optional("task"): TASK_TEMPLATE_SCHEMA,
    vol.Optional("enabled"): bool,
    vol.Optional("combine"): vol.In(("and", "or")),
    vol.Optional("window_from"): vol.Any("", hh_mm),
    vol.Optional("window_to"): vol.Any("", hh_mm),
    vol.Optional("days_ahead"): vol.All(vol.Coerce(int), vol.Range(min=0, max=MAX_DAYS_AHEAD)),
    vol.Optional("paused_until"): vol.Any(None, iso_date),
}


def _calendar_entity(value: object) -> str:
    value = str(value or "").strip()
    if value and not value.startswith("calendar."):
        raise vol.Invalid("A custom period needs a calendar entity")
    return value


PERIOD_RULE_NAME = vol.All(str, vol.Strip, vol.Length(min=1))

PERIOD_RULE_FIELDS = {
    vol.Optional("name"): PERIOD_RULE_NAME,
    vol.Optional("calendar"): _calendar_entity,
    vol.Optional("anchor_match"): vol.All(str, vol.Strip),
    vol.Optional("anchor_part"): vol.In(ANCHOR_PARTS),
    vol.Optional("anchor_weekdays"): [vol.All(vol.Coerce(int), vol.Range(min=0, max=6))],
    vol.Optional("start_offset"): vol.All(vol.Coerce(int), vol.Range(min=-MAX_OFFSET, max=MAX_OFFSET)),
    vol.Optional("end_offset"): vol.All(vol.Coerce(int), vol.Range(min=-MAX_OFFSET, max=MAX_OFFSET)),
    vol.Optional("max_events"): vol.Any(None, vol.All(vol.Coerce(int), vol.Range(min=0))),
    vol.Optional("count_match"): vol.All(str, vol.Strip),
    vol.Optional("horizon_days"): vol.All(vol.Coerce(int), vol.Range(min=7, max=MAX_HORIZON_DAYS)),
    vol.Optional("enabled"): bool,
}
