"""Import of a Microsoft To Do export (raw Microsoft Graph data, see tools/ms_todo_export.py)."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timedelta, timezone, tzinfo
import html
import re
from typing import Any

from .collection import TaskCollection
from .models import Task, new_id
from .period import Granularity, Period

EXTERNAL_PREFIX = "ms_todo:"

_RECURRENCE_UNITS = {
    "daily": Granularity.DAY,
    "weekly": Granularity.WEEK,
    "absoluteMonthly": Granularity.MONTH,
    "relativeMonthly": Granularity.MONTH,
    "absoluteYearly": Granularity.YEAR,
    "relativeYearly": Granularity.YEAR,
}


@dataclass(slots=True)
class ImportOptions:
    include_completed: bool = True
    skip_flagged_emails: bool = True
    # Tasks due on the last day of a month become "due in that month".
    convert_month_ends: bool = False
    # Tasks due on a Sunday become "due in that week".
    convert_sundays: bool = False


@dataclass(slots=True)
class ImportResult:
    dry_run: bool
    lists_created: list[str] = field(default_factory=list)
    lists_merged: list[str] = field(default_factory=list)
    tasks_imported: int = 0
    tasks_completed: int = 0
    tasks_skipped_existing: int = 0
    tasks_skipped_completed: int = 0
    converted_to_month: int = 0
    converted_to_week: int = 0
    # Day tasks that look like they were meant for a whole month/week.
    month_end_candidates: int = 0
    sunday_candidates: int = 0
    warnings: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def _parse_graph_datetime(value: dict[str, Any] | None) -> datetime | None:
    """Parse a Graph dateTimeTimeZone. The export requests UTC, anything else is treated as UTC too."""
    if not value or not value.get("dateTime"):
        return None
    # Graph sends seven fractional digits, which fromisoformat does not accept.
    text = re.sub(r"(\.\d{6})\d+", r"\1", value["dateTime"].rstrip("Z"))
    parsed = datetime.fromisoformat(text)
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _due_date(value: dict[str, Any] | None, tz: tzinfo) -> date | None:
    """Due dates are whole days stored as (roughly) local midnight; round to the nearest midnight."""
    parsed = _parse_graph_datetime(value)
    if parsed is None:
        return None
    return (parsed.astimezone(tz) + timedelta(hours=12)).date()


def _notes(body: dict[str, Any] | None) -> str:
    if not body or not body.get("content"):
        return ""
    content = body["content"]
    if body.get("contentType") == "html":
        content = re.sub(r"<br\s*/?>|</p>|</div>", "\n", content, flags=re.IGNORECASE)
        content = html.unescape(re.sub(r"<[^>]+>", "", content))
    return content.strip()


def _iso(value: str | None) -> str | None:
    if not value:
        return None
    return _parse_graph_datetime({"dateTime": value}).isoformat()


def convert_task(raw: dict[str, Any], options: ImportOptions, tz: tzinfo, result: ImportResult) -> dict[str, Any]:
    """Graph todoTask -> serialized tHAsk task fields (without id, list and position)."""
    title = (raw.get("title") or "").strip() or "(ohne Titel)"
    fields: dict[str, Any] = {
        "title": title,
        "notes": _notes(raw.get("body")),
        "important": raw.get("importance") == "high",
        "completed": raw.get("status") == "completed",
        "categories": list(raw.get("categories") or []),
        "steps": [
            {"title": item.get("displayName") or "", "completed": bool(item.get("isChecked"))}
            for item in raw.get("checklistItems") or []
        ],
        "external_id": EXTERNAL_PREFIX + raw["id"],
    }
    for key, graph_key in (("created", "createdDateTime"), ("modified", "lastModifiedDateTime")):
        if value := _iso(raw.get(graph_key)):
            fields[key] = value
    if fields["completed"]:
        completed = _parse_graph_datetime(raw.get("completedDateTime"))
        fields["completed_at"] = (completed or datetime.now(timezone.utc)).isoformat()

    if (due_day := _due_date(raw.get("dueDateTime"), tz)) is not None:
        period = Period.day(due_day)
        month_end = due_day == Period(Granularity.MONTH, due_day).end
        sunday = due_day.weekday() == 6
        result.month_end_candidates += month_end
        result.sunday_candidates += sunday
        if month_end and options.convert_month_ends:
            period = Period(Granularity.MONTH, due_day)
            result.converted_to_month += 1
        elif sunday and options.convert_sundays:
            period = Period(Granularity.WEEK, due_day)
            result.converted_to_week += 1
        fields["due"] = period.as_dict()

        if pattern := (raw.get("recurrence") or {}).get("pattern"):
            if unit := _RECURRENCE_UNITS.get(pattern.get("type", "")):
                fields["recurrence"] = {"unit": unit.value, "interval": max(1, int(pattern.get("interval") or 1))}
                if unit is Granularity.WEEK and len(pattern.get("daysOfWeek") or []) > 1:
                    result.warnings.append(
                        f"„{title}“: wiederholt sich an mehreren Wochentagen, übernommen als wöchentlich"
                    )
            else:
                result.warnings.append(f"„{title}“: Wiederholung „{pattern.get('type')}“ nicht übernommen")

    if raw.get("isReminderOn") and (reminder := _parse_graph_datetime(raw.get("reminderDateTime"))):
        fields["reminder"] = reminder.isoformat()
    if raw.get("hasAttachments"):
        result.warnings.append(f"„{title}“: Anhänge wurden nicht übernommen")
    return fields


def import_export(
    collection: TaskCollection,
    export: dict[str, Any],
    options: ImportOptions,
    tz: tzinfo,
    *,
    dry_run: bool,
) -> ImportResult:
    """Import lists and tasks. Lists are matched by origin or name, tasks already imported are skipped."""
    if export.get("source") != "ms_todo" or not isinstance(export.get("lists"), list):
        raise ValueError("Keine gültige MS-To-Do-Exportdatei")
    result = ImportResult(dry_run=dry_run)
    by_name = {item.name.casefold(): item for item in collection.lists.values()}

    for raw_list in export["lists"]:
        if options.skip_flagged_emails and raw_list.get("wellknownListName") == "flaggedEmails":
            continue
        name = raw_list.get("displayName") or "MS To Do"
        external_list_id = EXTERNAL_PREFIX + raw_list["id"]
        target = collection.find_external_list(external_list_id) or by_name.get(name.casefold())
        if target is None:
            result.lists_created.append(name)
            if not dry_run:
                target = collection.create_list(name, external_id=external_list_id)
                by_name[name.casefold()] = target
        elif name not in result.lists_merged:
            result.lists_merged.append(name)

        # Oldest first, each placed on top, so the newest ends up first as in To Do.
        tasks = sorted(raw_list.get("tasks") or [], key=lambda raw: raw.get("createdDateTime") or "")
        for raw in tasks:
            if collection.find_external(EXTERNAL_PREFIX + raw["id"]):
                result.tasks_skipped_existing += 1
                continue
            if raw.get("status") == "completed" and not options.include_completed:
                result.tasks_skipped_completed += 1
                continue
            fields = convert_task(raw, options, tz, result)
            result.tasks_imported += 1
            result.tasks_completed += fields["completed"]
            if dry_run or target is None:
                continue
            task = Task.from_dict({**fields, "id": new_id(), "list_id": target.id})
            task.position = collection.top_position(target.id)
            collection.add_task(task)
    return result
