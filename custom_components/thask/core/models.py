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
    """Repeat every `interval` units. The next due period keeps the task's granularity."""

    unit: Granularity
    interval: int = 1

    def next_period(self, period: Period, today: date) -> Period:
        """The next period after `period` that has not already ended before today."""
        following = period.shift(self.interval, self.unit)
        while following.end < today:
            following = following.shift(self.interval, self.unit)
        return following

    def as_dict(self) -> dict[str, Any]:
        return {"unit": self.unit.value, "interval": self.interval}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Recurrence:
        return cls(Granularity(data["unit"]), int(data.get("interval", 1)))


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


@dataclass(slots=True)
class TaskList:
    id: str
    name: str
    group: str | None = None
    color: str | None = None
    icon: str | None = None
    position: float = 0
    # Id in the system the list was imported from.
    external_id: str | None = None
    created: str = field(default_factory=utc_now_iso)
    modified: str = field(default_factory=utc_now_iso)

    EDITABLE = ("name", "group", "color", "icon", "position")

    def apply(self, patch: dict[str, Any]) -> None:
        for key in self.EDITABLE:
            if key in patch:
                setattr(self, key, patch[key])
        self.modified = utc_now_iso()

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "group": self.group,
            "color": self.color,
            "icon": self.icon,
            "position": self.position,
            "external_id": self.external_id,
            "created": self.created,
            "modified": self.modified,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> TaskList:
        return cls(**{key: data[key] for key in cls.__dataclass_fields__ if key in data})


@dataclass(slots=True)
class Task:
    id: str
    list_id: str
    title: str
    notes: str = ""
    completed: bool = False
    important: bool = False
    due: Period | None = None
    # Optional time of day, only meaningful for day periods ("HH:MM").
    due_time: str | None = None
    # Aware ISO datetime.
    reminder: str | None = None
    recurrence: Recurrence | None = None
    # ISO date of the day the task was added to "My Day"; stale values simply mean "not in My Day".
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
        "list_id", "title", "notes", "completed", "important", "due", "due_time", "reminder",
        "recurrence", "my_day", "steps", "categories", "position",
    )

    def apply(self, patch: dict[str, Any]) -> None:
        """Apply a partial update in serialized form (as sent by clients)."""
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

    def in_my_day(self, today: date) -> bool:
        return self.my_day == today.isoformat()

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
            important=self.important,
            due=due,
            due_time=self.due_time,
            reminder=reminder,
            recurrence=Recurrence(self.recurrence.unit, self.recurrence.interval),
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
            "important": self.important,
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
