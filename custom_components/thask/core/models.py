"""Data model for task lists and tasks."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone, tzinfo
from typing import Any
from uuid import uuid4

from .period import Granularity, Period


def new_id() -> str:
    return uuid4().hex


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(slots=True)
class Recurrence:
    """Repeat every `interval` units. The next due period keeps the task's granularity.

    Weekly recurrences of a day can name several weekdays (0 = Monday): "every Wednesday and Saturday",
    with an interval "every other week on Monday and Thursday".
    """

    unit: Granularity
    interval: int = 1
    weekdays: tuple[int, ...] = ()

    def __post_init__(self) -> None:
        self.weekdays = tuple(sorted({int(day) for day in self.weekdays if 0 <= int(day) <= 6}))

    def next_period(self, period: Period, today: date) -> Period:
        """The next period after `period` that has not already ended before today."""
        if self.weekdays and self.unit is Granularity.WEEK and period.granularity is Granularity.DAY:
            return Period.day(self._next_weekday(period.start, today))
        following = period.shift(self.interval, self.unit)
        while following.end < today:
            following = following.shift(self.interval, self.unit)
        return following

    def _next_weekday(self, day: date, today: date) -> date:
        # Weeks are counted from the week of the current due day, so "every other week" stays in step.
        anchor = day - timedelta(days=day.weekday())
        while True:
            day += timedelta(days=1)
            weeks = (day - anchor).days // 7
            if weeks % self.interval == 0 and day.weekday() in self.weekdays and day >= today:
                return day

    def first_day(self, today: date) -> date:
        """The first of the weekdays from today on, for a new task without a due date."""
        return next(today + timedelta(days=offset) for offset in range(7) if (today.weekday() + offset) % 7 in self.weekdays)

    def copy(self) -> Recurrence:
        return Recurrence(self.unit, self.interval, self.weekdays)

    def as_dict(self) -> dict[str, Any]:
        data: dict[str, Any] = {"unit": self.unit.value, "interval": self.interval}
        if self.weekdays:
            data["weekdays"] = list(self.weekdays)
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Recurrence:
        unit = Granularity(data["unit"])
        weekdays = tuple(data.get("weekdays") or ()) if unit is Granularity.WEEK else ()
        return cls(unit, int(data.get("interval", 1)), weekdays)


@dataclass(slots=True)
class Step:
    id: str
    title: str
    completed: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {"id": self.id, "title": self.title, "completed": self.completed}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Step:
        return cls(data.get("id") or new_id(), data["title"], bool(data.get("completed", False)))


TASK_SORTS = ("manual", "priority", "due", "title", "created")
# Priority levels: 0 none, 1 low (green), 2 medium (orange), 3 high (red).
PRIORITIES = (0, 1, 2, 3)
PRIORITY_HIGH = 3


def normalize_sort(mode: str) -> str:
    """Older clients and stored lists use "important" for what is now the priority sort."""
    return "priority" if mode == "important" else mode


def sort_tasks(tasks: list[Task], mode: str) -> list[Task]:
    """Order tasks by a list's sort mode; ties keep the manual order."""
    manual = sorted(tasks, key=lambda task: (task.position, task.created))
    match mode:
        case "priority":
            return sorted(manual, key=lambda task: -task.priority)
        case "due":
            return sorted(manual, key=lambda task: task.due.end if task.due else date.max)
        case "title":
            return sorted(manual, key=lambda task: task.title.casefold())
        case "created":
            return sorted(manual, key=lambda task: task.created, reverse=True)
    return manual


@dataclass(slots=True)
class TaskList:
    id: str
    name: str
    group: str | None = None
    color: str | None = None
    icon: str | None = None
    position: float = 0
    # How the list's tasks are ordered: manual (by position) or one of TASK_SORTS.
    sort: str = "manual"
    # Id in the system the list was imported from.
    external_id: str | None = None
    created: str = field(default_factory=utc_now_iso)
    modified: str = field(default_factory=utc_now_iso)

    EDITABLE = ("name", "group", "color", "icon", "position", "sort")

    def apply(self, patch: dict[str, Any]) -> None:
        for key in self.EDITABLE:
            if key in patch:
                setattr(self, key, patch[key])
        self.sort = normalize_sort(self.sort)
        self.modified = utc_now_iso()

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "group": self.group,
            "color": self.color,
            "icon": self.icon,
            "position": self.position,
            "sort": self.sort,
            "external_id": self.external_id,
            "created": self.created,
            "modified": self.modified,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> TaskList:
        result = cls(**{key: data[key] for key in cls.__dataclass_fields__ if key in data})
        result.sort = normalize_sort(result.sort)
        return result


def this_week_range(today: date, rolling: bool = False) -> tuple[date, date]:
    """First and last day of "This week": the calendar week, or with `rolling` today and the next seven days.

    Seven days and not six, so that on a Sunday next week's period ("week 45") is already in it.
    """
    if rolling:
        return today, today + timedelta(days=7)
    week = Period(Granularity.WEEK, today)
    return week.start, week.end


@dataclass(slots=True)
class Task:
    id: str
    list_id: str
    title: str
    notes: str = ""
    completed: bool = False
    priority: int = 0
    due: Period | None = None
    # Optional time of day, only meaningful for day periods ("HH:MM").
    due_time: str | None = None
    # Aware ISO datetime.
    reminder: str | None = None
    recurrence: Recurrence | None = None
    # Deprecated: ISO date of the day the task was added to the former "My Day". "Today" now shows what is
    # due; the field is kept so older clients can still send it.
    my_day: str | None = None
    steps: list[Step] = field(default_factory=list)
    categories: list[str] = field(default_factory=list)
    position: float = 0
    # Id in the system the task was imported from, to make imports idempotent.
    external_id: str | None = None
    created: str = field(default_factory=utc_now_iso)
    modified: str = field(default_factory=utc_now_iso)
    completed_at: str | None = None

    EDITABLE = (
        "list_id", "title", "notes", "completed", "priority", "due", "due_time", "reminder",
        "recurrence", "my_day", "steps", "categories", "position",
    )

    def apply(self, patch: dict[str, Any]) -> None:
        """Apply a partial update in serialized form (as sent by clients)."""
        if "important" in patch and "priority" not in patch:
            # Legacy flag (older clients, stored data): important means high priority.
            patch = {**patch, "priority": PRIORITY_HIGH if patch["important"] else 0}
        for key in self.EDITABLE:
            if key not in patch:
                continue
            value = patch[key]
            match key:
                case "due":
                    value = Period.from_dict(value) if value else None
                case "recurrence":
                    value = Recurrence.from_dict(value) if value else None
                case "steps":
                    value = [Step.from_dict(step) for step in value]
                case "completed":
                    if value and not self.completed:
                        self.completed_at = utc_now_iso()
                    elif not value:
                        self.completed_at = None
            setattr(self, key, value)
        if self.due is None or self.due.granularity is not Granularity.DAY:
            self.due_time = None
        self.modified = utc_now_iso()

    def in_today(self, today: date, tz: tzinfo, overdue: bool = True, days_only: bool = False) -> bool:
        """The "Today" view: open tasks due by today, and those completed today.

        Overdue tasks are left out when `overdue` is false (they then have a view of their own). With
        `days_only` a period that ends today ("week 44" on a Sunday) belongs to "This week" instead.
        """
        if not self.due_by(today):
            return False
        if days_only and self.due.granularity is not Granularity.DAY and self.due.end >= today:
            return False
        if self.completed:
            return self.completed_on_or_after(today, tz)
        return overdue or not self.overdue(today)

    def in_this_week(self, today: date, tz: tzinfo, separate: bool = False, rolling: bool = False) -> bool:
        """The "This week" view: due by Sunday (overdue tasks included), and those completed this week.

        With `separate` it leaves out what "Today" shows when that only has days: overdue tasks and days due today.
        With `rolling` the week is today and the next seven days (see `this_week_range`).
        """
        start, end = this_week_range(today, rolling)
        if not self.due_by(end):
            return False
        if separate and (self.due.end < today or (self.due.granularity is Granularity.DAY and self.due.end == today)):
            return False
        return not self.completed or self.completed_on_or_after(start, tz)

    def in_this_month(self, today: date, tz: tzinfo, separate: bool = False, rolling: bool = False) -> bool:
        """The "This month" view: due by the end of the month; with `separate` only what is due after this week."""
        month = Period(Granularity.MONTH, today)
        if not self.due_by(month.end):
            return False
        if separate and self.due.end <= this_week_range(today, rolling)[1]:
            return False
        return not self.completed or self.completed_on_or_after(month.start, tz)

    def overdue(self, today: date) -> bool:
        """Open and due before today."""
        return not self.completed and self.due is not None and self.due.end < today

    def due_by(self, day: date) -> bool:
        """Whether the task has to be done by the end of `day` (overdue tasks included)."""
        return self.due is not None and self.due.end <= day

    def completed_on_or_after(self, day: date, tz: tzinfo) -> bool:
        if not self.completed_at:
            return False
        return datetime.fromisoformat(self.completed_at).astimezone(tz).date() >= day

    def next_occurrence(self, today: date) -> Task | None:
        """A fresh copy for the next due period of a recurring task, or None."""
        if self.recurrence is None or self.due is None:
            return None
        due = self.recurrence.next_period(self.due, today)
        reminder = None
        if self.reminder:
            offset = due.start - self.due.start
            reminder = (datetime.fromisoformat(self.reminder) + timedelta(days=offset.days)).isoformat()
        return Task(
            id=new_id(),
            list_id=self.list_id,
            title=self.title,
            notes=self.notes,
            priority=self.priority,
            due=due,
            due_time=self.due_time,
            reminder=reminder,
            recurrence=self.recurrence.copy(),
            steps=[Step(new_id(), step.title) for step in self.steps],
            categories=list(self.categories),
            position=self.position,
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "list_id": self.list_id,
            "title": self.title,
            "notes": self.notes,
            "completed": self.completed,
            "priority": self.priority,
            # Deprecated: kept for clients that still show a star.
            "important": self.priority >= PRIORITY_HIGH,
            "due": self.due.as_dict() if self.due else None,
            "due_time": self.due_time,
            "reminder": self.reminder,
            "recurrence": self.recurrence.as_dict() if self.recurrence else None,
            "my_day": self.my_day,
            "steps": [step.as_dict() for step in self.steps],
            "categories": self.categories,
            "position": self.position,
            "external_id": self.external_id,
            "created": self.created,
            "modified": self.modified,
            "completed_at": self.completed_at,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Task:
        task = cls(id=data["id"], list_id=data["list_id"], title=data["title"])
        task.apply(data)
        for key in ("external_id", "created", "modified", "completed_at"):
            if key in data:
                setattr(task, key, data[key])
        return task
