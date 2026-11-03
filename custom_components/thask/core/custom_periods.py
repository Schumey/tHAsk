"""Custom periods: named stretches of days that a rule finds in a calendar.

"After a night shift that ends on a Wednesday, from Thursday to the Friday after next, if the shift
calendar has at most 3 events then: that is an X block." A rule has an anchor (events whose title contains
a text, on their first or last day, optionally only on certain weekdays), the period relative to the
anchor day (start and end offset in days) and a limit for the events within the period.

The integration asks the calendar regularly and keeps the periods found ("instances"); tasks then get one
of them as their due period (Period with granularity "custom"), and keep it when the calendar changes.

No Home Assistant dependency: events come from a `Source` as for the triggers.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any, Literal

from .collection import NotFoundError
from .models import new_id, utc_now_iso
from .period import Period
from .triggers import CalendarEvent, Source

DATA_VERSION = 1
ANCHOR_PARTS = ("start", "end")
MAX_OFFSET = 60
DEFAULT_HORIZON_DAYS = 120
MAX_HORIZON_DAYS = 365


@dataclass(slots=True)
class PeriodRule:
    id: str
    name: str
    # calendar.* entity with the events.
    calendar: str = ""
    # Anchor events: title contains this text ("" = every event), counted on their first or last day.
    anchor_match: str = ""
    anchor_part: Literal["start", "end"] = "end"
    # Only anchors on these weekdays (0 = Monday); empty = every day.
    anchor_weekdays: tuple[int, ...] = ()
    # The period, in days after the anchor day (Wednesday + 1 = Thursday, + 9 = the Friday after next).
    start_offset: int = 1
    end_offset: int = 9
    # At most this many events in the period (None = no limit); only those whose title contains `count_match`.
    max_events: int | None = 3
    count_match: str = ""
    # How far ahead the calendar is asked.
    horizon_days: int = DEFAULT_HORIZON_DAYS
    enabled: bool = True
    created: str = field(default_factory=utc_now_iso)
    modified: str = field(default_factory=utc_now_iso)

    EDITABLE = (
        "name", "calendar", "anchor_match", "anchor_part", "anchor_weekdays", "start_offset", "end_offset",
        "max_events", "count_match", "horizon_days", "enabled",
    )

    def apply(self, patch: dict[str, Any]) -> None:
        for key in self.EDITABLE:
            if key in patch:
                setattr(self, key, patch[key])
        self.anchor_weekdays = tuple(sorted({int(day) for day in self.anchor_weekdays or () if 0 <= int(day) <= 6}))
        self.anchor_part = self.anchor_part if self.anchor_part in ANCHOR_PARTS else "end"
        self.start_offset = max(-MAX_OFFSET, min(int(self.start_offset or 0), MAX_OFFSET))
        self.end_offset = max(self.start_offset, min(int(self.end_offset or 0), MAX_OFFSET))
        self.max_events = None if self.max_events is None or self.max_events == "" else max(0, int(self.max_events))
        self.horizon_days = max(7, min(int(self.horizon_days or DEFAULT_HORIZON_DAYS), MAX_HORIZON_DAYS))
        self.modified = utc_now_iso()

    def find(self, events: list[CalendarEvent], tz: Any, today: date) -> list[Period]:
        """The periods the events give that have not ended before today, in order."""
        anchor_text = self.anchor_match.strip().casefold()
        count_text = self.count_match.strip().casefold()
        found: dict[tuple[date, date], Period] = {}
        for anchor in events:
            if anchor_text not in anchor.summary.casefold():
                continue
            first, last = anchor.days(tz)
            day = first if self.anchor_part == "start" else last
            if self.anchor_weekdays and day.weekday() not in self.anchor_weekdays:
                continue
            start, end = day + timedelta(days=self.start_offset), day + timedelta(days=self.end_offset)
            if end < today or (start, end) in found:
                continue
            if self.max_events is not None:
                inside = [
                    event for event in events
                    if event is not anchor and count_text in event.summary.casefold() and _overlaps(event, start, end, tz)
                ]
                if len(inside) > self.max_events:
                    continue
            found[start, end] = Period.custom(start, end, self.name, self.id)
        return sorted(found.values(), key=lambda period: period.start)

    def window(self, today: date) -> tuple[date, date]:
        """Days to ask the calendar for: back far enough for an anchor whose period is still running."""
        back = max(self.end_offset, 0) + 1
        ahead = self.horizon_days + max(-self.start_offset, 0)
        return today - timedelta(days=back), today + timedelta(days=ahead)

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "calendar": self.calendar,
            "anchor_match": self.anchor_match,
            "anchor_part": self.anchor_part,
            "anchor_weekdays": list(self.anchor_weekdays),
            "start_offset": self.start_offset,
            "end_offset": self.end_offset,
            "max_events": self.max_events,
            "count_match": self.count_match,
            "horizon_days": self.horizon_days,
            "enabled": self.enabled,
            "created": self.created,
            "modified": self.modified,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> PeriodRule:
        rule = cls(id=data["id"], name=data.get("name", ""))
        rule.apply(data)
        for key in ("created", "modified"):
            if key in data:
                setattr(rule, key, data[key])
        return rule


def _overlaps(event: CalendarEvent, start: date, end: date, tz: Any) -> bool:
    first, last = event.days(tz)
    return first <= end and start <= last


class PeriodBook:
    """The rules and the periods last found for each."""

    def __init__(self) -> None:
        self.rules: dict[str, PeriodRule] = {}
        self.instances: dict[str, list[Period]] = {}
        # Problems of the last refresh (unreachable calendar …), per rule id.
        self.errors: dict[str, str] = {}
        self._listeners: list[Callable[[], None]] = []

    def load(self, data: dict[str, Any]) -> None:
        self.rules = {item["id"]: PeriodRule.from_dict(item) for item in data.get("rules", [])}
        # Kept across restarts, so tasks can get a period before the calendar answers.
        self.instances = {
            rule_id: [Period.from_dict(item) for item in items]
            for rule_id, items in (data.get("instances") or {}).items()
            if rule_id in self.rules
        }

    def dump(self) -> dict[str, Any]:
        return {
            "version": DATA_VERSION,
            "rules": [rule.as_dict() for rule in self.rules.values()],
            "instances": {
                rule_id: [period.as_dict() for period in periods] for rule_id, periods in self.instances.items()
            },
        }

    def subscribe(self, listener: Callable[[], None]) -> Callable[[], None]:
        self._listeners.append(listener)
        return lambda: self._listeners.remove(listener)

    def _changed(self) -> None:
        for listener in list(self._listeners):
            listener()

    def get(self, rule_id: str) -> PeriodRule:
        try:
            return self.rules[rule_id]
        except KeyError:
            raise NotFoundError(rule_id) from None

    def sorted_rules(self) -> list[PeriodRule]:
        return sorted(self.rules.values(), key=lambda rule: (rule.name.casefold(), rule.created))

    def create(self, fields: dict[str, Any]) -> PeriodRule:
        rule = PeriodRule(id=new_id(), name="")
        rule.apply(fields)
        self.rules[rule.id] = rule
        self._changed()
        return rule

    def update(self, rule_id: str, patch: dict[str, Any]) -> PeriodRule:
        rule = self.get(rule_id)
        rule.apply(patch)
        # Found periods carry the name.
        self.instances[rule_id] = [
            Period.custom(period.start, period.end, rule.name, rule.id) for period in self.instances.get(rule_id, [])
        ]
        self._changed()
        return rule

    def delete(self, rule_id: str) -> None:
        self.get(rule_id)
        del self.rules[rule_id]
        self.instances.pop(rule_id, None)
        self.errors.pop(rule_id, None)
        self._changed()

    def upcoming(self, rule_id: str, today: date) -> list[Period]:
        """Found periods of a rule that have not ended before today."""
        return [period for period in self.instances.get(rule_id, []) if period.end >= today]

    def next_after(self, rule_id: str, after: date, today: date) -> Period | None:
        """The first found period that starts after `after` and has not ended before today."""
        return next((p for p in self.upcoming(rule_id, today) if p.start > after), None)

    def find_by_name(self, name: str) -> PeriodRule | None:
        wanted = name.strip().casefold()
        return next((rule for rule in self.sorted_rules() if rule.name.strip().casefold() == wanted), None)

    async def refresh(self, source: Source, today: date, tz: Any, rule_ids: list[str] | None = None) -> None:
        """Ask the calendars again; a rule whose calendar fails keeps what it found before."""
        for rule in self.sorted_rules():
            if rule_ids is not None and rule.id not in rule_ids:
                continue
            if not rule.enabled or not rule.calendar:
                self.instances[rule.id] = []
                self.errors.pop(rule.id, None)
                continue
            start, end = rule.window(today)
            try:
                events = await source.events(rule.calendar, start, end)
            except Exception as err:  # noqa: BLE001 - a failing calendar must not stop the other rules
                self.errors[rule.id] = str(err) or type(err).__name__
                continue
            self.errors.pop(rule.id, None)
            self.instances[rule.id] = rule.find(events, tz, today)
        self._changed()

    def public(self, today: date) -> list[dict[str, Any]]:
        """What the apps need: name and upcoming periods per enabled rule."""
        return [
            {"id": rule.id, "name": rule.name, "instances": [p.as_dict() for p in self.upcoming(rule.id, today)]}
            for rule in self.sorted_rules()
            if rule.enabled
        ]
