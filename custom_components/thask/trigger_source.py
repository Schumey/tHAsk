"""Entity states and calendar events from Home Assistant for the trigger checks."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta

from homeassistant.core import HomeAssistant
from homeassistant.exceptions import HomeAssistantError
from homeassistant.util import dt as dt_util

from .core.triggers import CalendarEvent, EntityState


def _parse(value: str) -> date | datetime:
    if len(value) == 10:
        return date.fromisoformat(value)
    parsed = dt_util.parse_datetime(value)
    if parsed is None:
        raise ValueError(f"Invalid date: {value}")
    return dt_util.as_local(parsed)


class HassSource:
    def __init__(self, hass: HomeAssistant) -> None:
        self.hass = hass

    def state(self, entity_id: str) -> EntityState | None:
        if (state := self.hass.states.get(entity_id)) is None:
            return None
        return EntityState(state.state, dt_util.as_local(state.last_changed))

    async def events(self, entity_id: str, start: date, end: date) -> list[CalendarEvent]:
        if self.hass.states.get(entity_id) is None:
            raise HomeAssistantError(f"{entity_id} not found")
        tz = dt_util.get_default_time_zone()
        response = await self.hass.services.async_call(
            "calendar",
            "get_events",
            {
                "entity_id": entity_id,
                "start_date_time": datetime.combine(start, time(), tz),
                "end_date_time": datetime.combine(end + timedelta(days=1), time(), tz),
            },
            blocking=True,
            return_response=True,
        )
        raw = (response or {}).get(entity_id, {}).get("events", [])
        return [
            CalendarEvent(str(item.get("summary", "")), _parse(item["start"]), _parse(item["end"]))
            for item in raw
            if item.get("start") and item.get("end")
        ]
