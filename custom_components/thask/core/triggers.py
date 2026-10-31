"""Triggers: create a task once per day when something in Home Assistant applies.

"If the calendar has an early shift tomorrow, add "Prepare early shift" today." A trigger has conditions
(state of an entity, calendar event, time of day), combined with AND or OR, and a task template.
State and time conditions judge the moment of the check; calendar conditions judge the day the task
is for, which may lie up to `days_ahead` days in the future. Each trigger fires at most once per day
and once per calendar event; the run history allows undoing a run.

No Home Assistant dependency: entity states and calendar events come from a `Source`.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta
import re
from typing import Any, Literal, Protocol

from .collection import NotFoundError, TaskCollection
from .models import new_id, utc_now_iso
from .period import Granularity, Period

DATA_VERSION = 1
CONDITION_KINDS = ("state", "calendar", "time")
CALENDAR_PARTS = ("any", "start", "end")
DUE_OPTIONS = ("none", "today", "day_before", "day", "week", "month")
MAX_DAYS_AHEAD = 60
# Runs are kept this long; they also prevent firing twice for a day.
RUN_RETENTION_DAYS = 90

_TRUTHY_STATES = ("on", "home", "true", "open")
_COMPARISON = re.compile(r"^\s*(<=|>=|<|>)\s*(-?\d+(?:[.,]\d+)?)\s*$")
_WEEKDAYS = {
    "de": ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"],
    "en": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
}


# -- what a source provides -------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class EntityState:
    state: str
    last_changed: datetime


@dataclass(frozen=True, slots=True)
class CalendarEvent:
    summary: str
    # Dates for all-day events (end exclusive, as in Home Assistant), aware datetimes otherwise.
    start: date | datetime
    end: date | datetime

    def days(self, tz: Any) -> tuple[date, date]:
        """First and last day the event covers (inclusive)."""
        if isinstance(self.start, datetime):
            first = self.start.astimezone(tz).date()
            end = self.end if isinstance(self.end, datetime) else datetime.combine(self.end, time())
            # An event ending at midnight does not cover the next day.
            last = (end.astimezone(tz) - timedelta(microseconds=1)).date()
            return first, max(first, last)
        end = self.end if not isinstance(self.end, datetime) else self.end.date()
        return self.start, max(self.start, end - timedelta(days=1))

    def key(self, entity_id: str) -> str:
        """Identifies the event across checks, so one event creates one task."""
        return f"{entity_id}|{self.summary}|{self.start.isoformat()}"


class Source(Protocol):
    """Access to Home Assistant, or a fake in tests."""

    def state(self, entity_id: str) -> EntityState | None: ...

    def events(self, entity_id: str, start: date, end: date) -> Awaitable[list[CalendarEvent]]:
        """Events overlapping the days start … end (inclusive)."""
        ...


# -- configuration ----------------------------------------------------------------------------


def _hh_mm(value: str) -> time | None:
    try:
        return time.fromisoformat(value.strip()) if value and value.strip() else None
    except ValueError:
        return None


@dataclass(slots=True)
class Condition:
    kind: Literal["state", "calendar", "time"]
    entity: str = ""
    # State: expected state ("" = on/home/true; "<5", ">=20" compare numbers). Calendar: text in the title
    # ("" = any event). Time: "HH:MM", from then on.
    match: str = ""
    negate: bool = False
    # State: the state must have lasted this long.
    hold_minutes: int = 0
    # Calendar: which days of an event count.
    part: Literal["any", "start", "end"] = "any"

    def as_dict(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "entity": self.entity,
            "match": self.match,
            "negate": self.negate,
            "hold_minutes": self.hold_minutes,
            "part": self.part,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Condition:
        return cls(
            kind=data["kind"],
            entity=data.get("entity", "") or "",
            match=data.get("match", "") or "",
            negate=bool(data.get("negate", False)),
            hold_minutes=int(data.get("hold_minutes", 0) or 0),
            part=data.get("part", "any") or "any",
        )


@dataclass(slots=True)
class TaskTemplate:
    """The task a trigger creates. The title may use {event}, {date}, {weekday} and {state}."""

    title: str
    list_id: str | None = None
    # Relative to the day the task is for: none, today (the day the trigger fires), day_before, day, week, month.
    due: str = "day"
    my_day: bool = False
    priority: int = 0
    notes: str = ""

    def as_dict(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "list_id": self.list_id,
            "due": self.due,
            "my_day": self.my_day,
            "priority": self.priority,
            "notes": self.notes,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> TaskTemplate:
        return cls(
            title=data["title"],
            list_id=data.get("list_id"),
            due=data.get("due", "day"),
            my_day=bool(data.get("my_day", False)),
            priority=int(data.get("priority", 0)),
            notes=data.get("notes", "") or "",
        )


@dataclass(slots=True)
class Trigger:
    id: str
    name: str
    conditions: list[Condition]
    task: TaskTemplate
    enabled: bool = True
    combine: Literal["and", "or"] = "and"
    # Only fire between these times of day ("HH:MM", either may be empty; may wrap past midnight).
    window_from: str = ""
    window_to: str = ""
    # Calendar conditions also look this many days ahead.
    days_ahead: int = 0
    # Inactive up to and including this day (ISO date).
    paused_until: str | None = None
    created: str = field(default_factory=utc_now_iso)
    modified: str = field(default_factory=utc_now_iso)

    EDITABLE = ("name", "conditions", "task", "enabled", "combine", "window_from", "window_to", "days_ahead", "paused_until")

    def apply(self, patch: dict[str, Any]) -> None:
        for key in self.EDITABLE:
            if key not in patch:
                continue
            value = patch[key]
            match key:
                case "conditions":
                    value = [Condition.from_dict(item) for item in value]
                case "task":
                    value = TaskTemplate.from_dict(value)
                case "days_ahead":
                    value = max(0, min(int(value or 0), MAX_DAYS_AHEAD))
            setattr(self, key, value)
        self.modified = utc_now_iso()

    def active(self, today: date) -> bool:
        return self.enabled and not (self.paused_until and today.isoformat() <= self.paused_until)

    def in_window(self, now: datetime) -> bool:
        start, end = _hh_mm(self.window_from), _hh_mm(self.window_to)
        current = now.time().replace(second=0, microsecond=0)
        if start and end:
            return start <= current <= end if start <= end else current >= start or current <= end
        if start:
            return current >= start
        if end:
            return current <= end
        return True

    def target_days(self, today: date) -> list[date]:
        """Days a task may be created for: today, plus days ahead when a calendar condition decides."""
        ahead = self.days_ahead if any(c.kind == "calendar" for c in self.conditions) else 0
        return [today + timedelta(days=offset) for offset in range(ahead + 1)]

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "conditions": [condition.as_dict() for condition in self.conditions],
            "task": self.task.as_dict(),
            "enabled": self.enabled,
            "combine": self.combine,
            "window_from": self.window_from,
            "window_to": self.window_to,
            "days_ahead": self.days_ahead,
            "paused_until": self.paused_until,
            "created": self.created,
            "modified": self.modified,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Trigger:
        trigger = cls(id=data["id"], name=data.get("name", ""), conditions=[], task=TaskTemplate(title=""))
        trigger.apply(data)
        for key in ("created", "modified"):
            if key in data:
                setattr(trigger, key, data[key])
        return trigger


@dataclass(slots=True)
class TriggerRun:
    id: str
    trigger_id: str
    # The day the task is for.
    day: str
    fired_at: str
    title: str
    task_id: str | None = None
    event_key: str | None = None
    # "Undo" removes the task; the run stays so the trigger does not fire again for that day.
    undone: bool = False
    manual: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "trigger_id": self.trigger_id,
            "day": self.day,
            "fired_at": self.fired_at,
            "title": self.title,
            "task_id": self.task_id,
            "event_key": self.event_key,
            "undone": self.undone,
            "manual": self.manual,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> TriggerRun:
        return cls(**{key: data[key] for key in cls.__dataclass_fields__ if key in data})


# -- evaluation -------------------------------------------------------------------------------


@dataclass(slots=True)
class Match:
    """Whether a trigger applies for a day, with what the title placeholders need."""

    met: bool
    results: list[bool]
    event: CalendarEvent | None = None
    event_entity: str | None = None
    state: str | None = None


def state_matches(state: str, expected: str) -> bool:
    expected = expected.strip()
    if not expected:
        return state.lower() in _TRUTHY_STATES
    if comparison := _COMPARISON.match(expected):
        try:
            value = float(state.replace(",", "."))
        except ValueError:
            return False
        limit = float(comparison[2].replace(",", "."))
        return {"<": value < limit, "<=": value <= limit, ">": value > limit, ">=": value >= limit}[comparison[1]]
    return state.casefold() == expected.casefold()


def _event_on(event: CalendarEvent, day: date, part: str, tz: Any) -> bool:
    first, last = event.days(tz)
    match part:
        case "start":
            return first == day
        case "end":
            return last == day
    return first <= day <= last


class Evaluator:
    """Judges conditions; calendar requests are cached for one check."""

    def __init__(self, source: Source, now: datetime) -> None:
        self.source = source
        self.now = now
        self._events: dict[tuple[str, date, date], list[CalendarEvent]] = {}

    async def _calendar(self, entity: str, start: date, end: date) -> list[CalendarEvent]:
        key = (entity, start, end)
        if key not in self._events:
            self._events[key] = await self.source.events(entity, start, end)
        return self._events[key]

    async def calendar_events(self, condition: Condition, day: date, horizon: date) -> list[CalendarEvent]:
        """Events of the condition's calendar on `day` whose title matches."""
        events = await self._calendar(condition.entity, self.now.date(), max(horizon, day))
        text = condition.match.strip().casefold()
        return [
            event for event in events
            if text in event.summary.casefold() and _event_on(event, day, condition.part, self.now.tzinfo)
        ]

    async def evaluate(self, trigger: Trigger, day: date, horizon: date | None = None) -> Match:
        horizon = horizon or day
        results: list[bool] = []
        found = Match(met=False, results=results)
        for condition in trigger.conditions:
            match condition.kind:
                case "time":
                    at = _hh_mm(condition.match)
                    ok = at is not None and self.now.time() >= at
                case "state":
                    current = self.source.state(condition.entity)
                    ok = current is not None and state_matches(current.state, condition.match)
                    if ok and condition.hold_minutes and not condition.negate:
                        ok = self.now - current.last_changed >= timedelta(minutes=condition.hold_minutes)
                    if current is not None and found.state is None:
                        found.state = current.state
                case _:
                    events = await self.calendar_events(condition, day, horizon)
                    ok = bool(events)
                    if events and not condition.negate and found.event is None:
                        found.event, found.event_entity = events[0], condition.entity
            results.append(ok != condition.negate)
        found.met = bool(results) and (any(results) if trigger.combine == "or" else all(results))
        return found


def render_title(template: str, match: Match | None, day: date, lang: str, today: date) -> str:
    lang = "de" if lang.startswith("de") else "en"
    values = {
        "event": match.event.summary if match and match.event else "",
        "date": Period.day(day).label(lang, today),
        "weekday": _WEEKDAYS[lang][day.weekday()],
        "state": match.state if match and match.state is not None else "",
    }
    aliases = {"termin": "event", "datum": "date", "wochentag": "weekday", "zustand": "state"}

    def replace(found: re.Match[str]) -> str:
        name = found[1].lower()
        name = aliases.get(name, name)
        return values[name] if name in values else found[0]

    title = re.sub(r"\{(\w+)\}", replace, template)
    return re.sub(r"\s+", " ", title).strip() or template


def due_for(option: str, day: date, today: date) -> Period | None:
    match option:
        case "today":
            return Period.day(today)
        case "day_before":
            # "Prepare the day before"; for an event today that is today, not an overdue yesterday.
            return Period.day(max(day - timedelta(days=1), today))
        case "day":
            return Period.day(day)
        case "week":
            return Period(Granularity.WEEK, day)
        case "month":
            return Period(Granularity.MONTH, day)
    return None


# -- triggers, runs and checking --------------------------------------------------------------


class TriggerBook:
    def __init__(self) -> None:
        self.triggers: dict[str, Trigger] = {}
        self.runs: list[TriggerRun] = []
        # Problems of the last check (unreachable calendar …), per trigger name.
        self.errors: list[str] = []
        self._listeners: list[Callable[[], None]] = []

    def load(self, data: dict[str, Any]) -> None:
        self.triggers = {item["id"]: Trigger.from_dict(item) for item in data.get("triggers", [])}
        self.runs = [TriggerRun.from_dict(item) for item in data.get("runs", [])]

    def dump(self) -> dict[str, Any]:
        return {
            "version": DATA_VERSION,
            "triggers": [trigger.as_dict() for trigger in self.triggers.values()],
            "runs": [run.as_dict() for run in self.runs],
        }

    def subscribe(self, listener: Callable[[], None]) -> Callable[[], None]:
        self._listeners.append(listener)
        return lambda: self._listeners.remove(listener)

    def _changed(self) -> None:
        for listener in list(self._listeners):
            listener()

    def get(self, trigger_id: str) -> Trigger:
        try:
            return self.triggers[trigger_id]
        except KeyError:
            raise NotFoundError(trigger_id) from None

    def sorted_triggers(self) -> list[Trigger]:
        return sorted(self.triggers.values(), key=lambda trigger: (trigger.name.casefold(), trigger.created))

    def create(self, fields: dict[str, Any]) -> Trigger:
        trigger = Trigger(id=new_id(), name="", conditions=[], task=TaskTemplate(title=""))
        trigger.apply(fields)
        self.triggers[trigger.id] = trigger
        self._changed()
        return trigger

    def update(self, trigger_id: str, patch: dict[str, Any]) -> Trigger:
        trigger = self.get(trigger_id)
        trigger.apply(patch)
        self._changed()
        return trigger

    def delete(self, trigger_id: str) -> None:
        self.get(trigger_id)
        del self.triggers[trigger_id]
        self.runs = [run for run in self.runs if run.trigger_id != trigger_id]
        self._changed()

    def recent_runs(self, limit: int = 30) -> list[TriggerRun]:
        return sorted(self.runs, key=lambda run: run.fired_at, reverse=True)[:limit]

    def has_run(self, trigger_id: str, day: date) -> bool:
        return any(run.trigger_id == trigger_id and run.day == day.isoformat() for run in self.runs)

    def has_event(self, trigger_id: str, event_key: str) -> bool:
        return any(run.trigger_id == trigger_id and run.event_key == event_key for run in self.runs)

    def prune(self, today: date) -> None:
        cutoff = (today - timedelta(days=RUN_RETENTION_DAYS)).isoformat()
        self.runs = [run for run in self.runs if run.day >= cutoff]

    def fire(
        self,
        trigger: Trigger,
        collection: TaskCollection,
        day: date,
        today: date,
        lang: str,
        match: Match | None = None,
        manual: bool = False,
    ) -> TriggerRun:
        """Create the trigger's task for `day` and remember the run."""
        template = trigger.task
        list_id = template.list_id if template.list_id in collection.lists else None
        if list_id is None:
            default = collection.default_list()
            if default is None:
                raise ValueError("No list to add the task to")
            list_id = default.id
        title = render_title(template.title, match, day, lang, today)
        fields: dict[str, Any] = {"priority": template.priority, "notes": template.notes}
        if due := due_for(template.due, day, today):
            fields["due"] = due.as_dict()
        if template.my_day:
            fields["my_day"] = today.isoformat()
        task = collection.create_task(list_id, title, **fields)
        event_key = match.event.key(match.event_entity or "") if match and match.event else None
        run = TriggerRun(
            id=new_id(),
            trigger_id=trigger.id,
            day=day.isoformat(),
            fired_at=utc_now_iso(),
            title=title,
            task_id=task.id,
            event_key=event_key,
            manual=manual,
        )
        self.runs.append(run)
        self._changed()
        return run

    def undo(self, run_id: str, collection: TaskCollection) -> TriggerRun:
        run = next((run for run in self.runs if run.id == run_id), None)
        if run is None:
            raise NotFoundError(run_id)
        if run.task_id and run.task_id in collection.tasks:
            collection.delete_task(run.task_id)
        run.undone = True
        self._changed()
        return run

    async def check(
        self, collection: TaskCollection, source: Source, now: datetime, lang: str
    ) -> list[TriggerRun]:
        """Fire every active trigger that applies and has not fired for its day yet."""
        today = now.date()
        self.prune(today)
        evaluator = Evaluator(source, now)
        fired: list[TriggerRun] = []
        self.errors = []
        for trigger in self.sorted_triggers():
            if not trigger.active(today) or not trigger.conditions or not trigger.in_window(now):
                continue
            days = trigger.target_days(today)
            for day in days:
                if self.has_run(trigger.id, day):
                    continue
                try:
                    match = await evaluator.evaluate(trigger, day, days[-1])
                except Exception as err:  # noqa: BLE001 - a failing source must not stop the other triggers
                    self.errors.append(f"{trigger.name}: {err}")
                    break
                if not match.met:
                    continue
                if match.event and self.has_event(trigger.id, match.event.key(match.event_entity or "")):
                    continue
                fired.append(self.fire(trigger, collection, day, today, lang, match))
        return fired
