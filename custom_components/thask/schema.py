"""Voluptuous schemas shared by the WebSocket API and the services. Values come out in serialized form."""

from __future__ import annotations

from datetime import datetime

import voluptuous as vol

from homeassistant.helpers import config_validation as cv
from homeassistant.util import dt as dt_util

from .core.models import TASK_SORTS
from .core.period import Granularity

GRANULARITIES = [granularity.value for granularity in Granularity]


def iso_date(value: object) -> str:
    return cv.date(value).isoformat()


def iso_datetime(value: object) -> str:
    parsed: datetime = cv.datetime(value)
    return dt_util.as_utc(parsed).isoformat()


def hh_mm(value: object) -> str:
    return cv.time(value).strftime("%H:%M")


PERIOD_SCHEMA = vol.Schema(
    {vol.Required("granularity"): vol.In(GRANULARITIES), vol.Required("start"): iso_date}
)

RECURRENCE_SCHEMA = vol.Schema(
    {
        vol.Required("unit"): vol.In(GRANULARITIES),
        vol.Optional("interval", default=1): vol.All(vol.Coerce(int), vol.Range(min=1)),
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
    vol.Optional("sort"): vol.In(TASK_SORTS),
}
