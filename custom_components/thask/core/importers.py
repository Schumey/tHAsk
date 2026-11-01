"""Import from other task apps: Todoist, Google Tasks, TickTick, generic CSV and iCalendar (VTODO).

Each reader turns an export into `ImportedList`s with tasks in serialized tHAsk form; `merge_lists` adds them
to the collection the same way as the Microsoft To Do import: lists are matched by origin or name, tasks that
were imported before are skipped, and a dry run only counts.
"""

from __future__ import annotations

import csv
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone, tzinfo
import hashlib
import io
import json
from pathlib import PurePath
import re
from typing import Any
import zipfile

from .collection import TaskCollection
from .models import Task, new_id
from .ms_todo import ImportResult
from .parser import parse
from .period import Granularity, Period

FORMATS = ["auto", "todoist", "google_tasks", "ticktick", "csv", "ical"]

_RRULE_DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
_RRULE_UNITS = {
    "DAILY": Granularity.DAY,
    "WEEKLY": Granularity.WEEK,
    "MONTHLY": Granularity.MONTH,
    "YEARLY": Granularity.YEAR,
}


@dataclass(slots=True)
class ImportedList:
    key: str
    name: str
    group: str | None = None
    # Serialized task fields, in display order (top first); each has an `external_id`.
    tasks: list[dict[str, Any]] = field(default_factory=list)


# -- Shared helpers --------------------------------------------------------------------------------------------


def _hash(*parts: Any) -> str:
    return hashlib.sha1("\x1f".join(str(part) for part in parts).encode()).hexdigest()[:16]


def _parse_datetime(text: str) -> datetime | None:
    """ISO 8601 in its common variants ("Z", "+0000", with or without seconds)."""
    text = text.strip()
    if not text:
        return None
    text = re.sub(r"Z$", "+00:00", text)
    text = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", text)
    text = re.sub(r"(\.\d{6})\d+", r"\1", text)
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _rrule(text: str) -> dict[str, Any] | None:
    """An iCalendar RRULE ("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH") as a tHAsk recurrence."""
    parts = dict(item.split("=", 1) for item in text.removeprefix("RRULE:").split(";") if "=" in item)
    unit = _RRULE_UNITS.get(parts.get("FREQ", "").upper())
    if unit is None:
        return None
    recurrence: dict[str, Any] = {"unit": unit.value, "interval": max(1, int(parts.get("INTERVAL") or 1))}
    days = [_RRULE_DAYS.index(day[-2:]) for day in parts.get("BYDAY", "").upper().split(",") if day[-2:] in _RRULE_DAYS]
    if unit is Granularity.WEEK and len(days) > 1:
        recurrence["weekdays"] = sorted(set(days))
    return recurrence


def _due_from_text(text: str, today: date, tz: tzinfo) -> tuple[dict[str, Any], str | None]:
    """Due date (and time) from a date cell: ISO, 31.12.2026, 12/31/2026 or anything the quick entry knows.

    Returns task fields and, if nothing matched, the text that was not understood.
    """
    text = text.strip()
    if not text:
        return {}, None
    if (moment := _parse_datetime(text)) is not None:
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", text):
            return {"due": Period.day(moment.date()).as_dict()}, None
        if moment.tzinfo is not None:
            moment = moment.astimezone(tz)
        fields: dict[str, Any] = {"due": Period.day(moment.date()).as_dict()}
        if moment.time() != time(0):
            fields["due_time"] = moment.strftime("%H:%M")
        return fields, None
    if match := re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{2,4})", text):
        day, month, year = (int(part) for part in match.groups())
        return _safe_day(year + 2000 if year < 100 else year, month, day, text)
    if match := re.fullmatch(r"(\d{1,2})/(\d{1,2})/(\d{2,4})", text):
        month, day, year = (int(part) for part in match.groups())
        return _safe_day(year + 2000 if year < 100 else year, month, day, text)
    result = parse(text, today)
    fields = {}
    if result.due is not None:
        fields["due"] = result.due.as_dict()
    if result.due_time:
        fields["due_time"] = result.due_time
    if result.recurrence is not None:
        fields["recurrence"] = result.recurrence.as_dict()
    return (fields, None) if fields else ({}, text)


def _safe_day(year: int, month: int, day: int, text: str) -> tuple[dict[str, Any], str | None]:
    try:
        return {"due": Period.day(date(year, month, day)).as_dict()}, None
    except ValueError:
        return {}, text


def _task(title: str, external_id: str, **fields: Any) -> dict[str, Any]:
    task: dict[str, Any] = {
        "title": title.strip() or "(ohne Titel)",
        "notes": "",
        "completed": False,
        "priority": 0,
        "steps": [],
        "categories": [],
        "external_id": external_id,
    }
    task.update({key: value for key, value in fields.items() if value is not None})
    if task["completed"] and "completed_at" not in task:
        task["completed_at"] = datetime.now(timezone.utc).isoformat()
    return task


def _read_csv(text: str) -> list[dict[str, str]]:
    sample = text[:4096]
    try:
        dialect: Any = csv.Sniffer().sniff(sample, delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    return list(csv.DictReader(io.StringIO(text), dialect=dialect))


def _decode(data: bytes) -> str:
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


# -- Todoist ---------------------------------------------------------------------------------------------------


def _todoist_project(name: str) -> str:
    # Backup files are called "Projekt [2203306141].csv".
    return re.sub(r"\s*\[\d+\]$", "", PurePath(name).stem).strip() or "Todoist"


def read_todoist(files: dict[str, str], today: date, tz: tzinfo, result: ImportResult) -> list[ImportedList]:
    """Todoist CSV, one file per project (a single export or all files of a backup ZIP)."""
    lists = []
    for name, text in files.items():
        project = _todoist_project(name)
        imported = ImportedList(key="todoist:" + project.casefold(), name=project)
        section: str | None = None
        parent: dict[str, Any] | None = None
        for row in _read_csv(text):
            kind = (row.get("TYPE") or "").strip().lower()
            content = (row.get("CONTENT") or "").strip()
            if kind == "section":
                section = content or None
                parent = None
                continue
            if kind == "note":
                if parent is not None and content:
                    parent["notes"] = (parent["notes"] + "\n\n" + content).strip()
                continue
            if kind != "task" or not content:
                continue
            labels = re.findall(r"(?<!\S)@([\w-]+)", content)
            title = re.sub(r"\s*(?<!\S)@[\w-]+", "", content).strip()
            if (row.get("INDENT") or "1").strip() not in ("", "1") and parent is not None:
                parent["steps"].append({"title": title, "completed": False})
                continue
            priority = {"1": 3, "2": 2, "3": 1}.get((row.get("PRIORITY") or "").strip(), 0)
            fields, unknown = _due_from_text(row.get("DATE") or "", today, tz)
            if unknown:
                result.warnings.append(f"„{title}“: Fälligkeit „{unknown}“ nicht erkannt")
            categories = labels + ([section] if section else [])
            parent = _task(
                title,
                "todoist:" + _hash(project, section, title, row.get("DATE")),
                notes=(row.get("DESCRIPTION") or "").strip(),
                priority=priority,
                categories=categories,
                **fields,
            )
            imported.tasks.append(parent)
        lists.append(imported)
    return lists


# -- Google Tasks ----------------------------------------------------------------------------------------------


def read_google_tasks(data: dict[str, Any], tz: tzinfo) -> list[ImportedList]:
    """Google Takeout `Tasks.json`. Subtasks become steps of their parent."""
    lists = []
    for raw_list in data.get("items") or []:
        imported = ImportedList(key="google_tasks:" + str(raw_list.get("id")), name=raw_list.get("title") or "Google Tasks")
        raw_tasks = [raw for raw in raw_list.get("items") or [] if not raw.get("deleted")]
        raw_tasks.sort(key=lambda raw: raw.get("position") or "")
        by_id: dict[str, dict[str, Any]] = {}
        for raw in raw_tasks:
            if raw.get("parent"):
                continue
            due = _parse_datetime(raw.get("due") or "")
            completed = raw.get("status") == "completed"
            task = _task(
                raw.get("title") or "",
                "google_tasks:" + str(raw.get("id")),
                notes=(raw.get("notes") or "").strip(),
                completed=completed,
                # Google stores the due day as midnight UTC; the time is not used.
                due=Period.day(due.date()).as_dict() if due else None,
                completed_at=_iso(raw.get("completed")) if completed else None,
                created=_iso(raw.get("created")),
                modified=_iso(raw.get("updated")),
            )
            by_id[str(raw.get("id"))] = task
            imported.tasks.append(task)
        for raw in raw_tasks:
            if (parent := by_id.get(str(raw.get("parent")))) is not None:
                parent["steps"].append({"title": raw.get("title") or "", "completed": raw.get("status") == "completed"})
        lists.append(imported)
    return lists


def _iso(value: str | None) -> str | None:
    moment = _parse_datetime(value or "")
    if moment is None:
        return None
    return (moment if moment.tzinfo else moment.replace(tzinfo=timezone.utc)).isoformat()


# -- TickTick --------------------------------------------------------------------------------------------------


def read_ticktick(text: str, tz: tzinfo, result: ImportResult) -> list[ImportedList]:
    """TickTick backup CSV (Settings → Backup): a few lines of preamble, then one row per task."""
    lines = text.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.lstrip('"').startswith("Folder Name")), None)
    if start is None:
        raise ValueError("Keine TickTick-Sicherung (Kopfzeile „Folder Name“ fehlt)")
    rows = list(csv.DictReader(io.StringIO("".join(lines[start:]))))
    lists: dict[str, ImportedList] = {}
    by_id: dict[str, dict[str, Any]] = {}
    children = []
    for row in rows:
        name = (row.get("List Name") or "").strip() or "TickTick"
        imported = lists.setdefault(
            name, ImportedList(key="ticktick:" + name.casefold(), name=name, group=(row.get("Folder Name") or "").strip() or None)
        )
        if (row.get("parentId") or "").strip():
            children.append(row)
            continue
        task = _ticktick_task(row, tz, result)
        by_id[(row.get("taskId") or "").strip()] = task
        imported.tasks.append(task)
    for row in children:
        if (parent := by_id.get(row["parentId"].strip())) is not None:
            parent["steps"].append({"title": (row.get("Title") or "").strip(), "completed": _ticktick_done(row)})
    for imported in lists.values():
        imported.tasks.sort(key=lambda task: task.pop("_order"))
    return list(lists.values())


def _ticktick_done(row: dict[str, str]) -> bool:
    return (row.get("Status") or "0").strip() in ("1", "2")


def _ticktick_task(row: dict[str, str], tz: tzinfo, result: ImportResult) -> dict[str, Any]:
    title = (row.get("Title") or "").strip()
    content = (row.get("Content") or "").strip()
    steps = []
    if (row.get("Is Check list") or "").strip().upper() == "Y":
        notes = []
        for line in content.splitlines():
            if match := re.match(r"\s*([▫▪✓☐☑])\s*(.*)", line):
                steps.append({"title": match[2].strip(), "completed": match[1] in "▪✓☑"})
            elif line.strip():
                notes.append(line.strip())
        content = "\n".join(notes)
    priority = int((row.get("Priority") or "0").strip() or 0)
    fields: dict[str, Any] = {}
    if due := _parse_datetime(row.get("Due Date") or ""):
        if due.tzinfo is not None:
            due = due.astimezone(tz)
        fields["due"] = Period.day(due.date()).as_dict()
        if (row.get("Is All Day") or "").strip().lower() != "true" and due.time() != time(0):
            fields["due_time"] = due.strftime("%H:%M")
    if (repeat := (row.get("Repeat") or "").strip()) and "due" in fields:
        if recurrence := _rrule(repeat):
            fields["recurrence"] = recurrence
        else:
            result.warnings.append(f"„{title}“: Wiederholung „{repeat}“ nicht übernommen")
    if (row.get("Reminder") or "").strip():
        result.warnings.append(f"„{title}“: Erinnerung nicht übernommen")
    done = _ticktick_done(row)
    task = _task(
        title,
        "ticktick:" + ((row.get("taskId") or "").strip() or _hash(row.get("List Name"), title)),
        notes=content,
        completed=done,
        priority=3 if priority >= 5 else 2 if priority >= 3 else 1 if priority >= 1 else 0,
        steps=steps,
        categories=[tag.strip() for tag in (row.get("Tags") or "").split(",") if tag.strip()],
        completed_at=_iso(row.get("Completed Time")) if done else None,
        created=_iso(row.get("Created Time")),
        **fields,
    )
    try:
        task["_order"] = float(row.get("Order") or 0)
    except ValueError:
        task["_order"] = 0.0
    return task


# -- Generic CSV -----------------------------------------------------------------------------------------------

# Column names that are recognized, in German and English (compared without case).
CSV_COLUMNS = {
    "title": ["title", "titel", "task", "aufgabe", "name", "subject", "betreff", "content", "summary"],
    "notes": ["notes", "notizen", "notiz", "description", "beschreibung", "body", "details"],
    "list": ["list", "liste", "project", "projekt", "list name", "folder"],
    "due": ["due", "due date", "fällig", "fälligkeit", "fällig am", "datum", "date", "deadline"],
    "priority": ["priority", "priorität", "prio", "importance", "wichtigkeit"],
    "completed": ["completed", "erledigt", "done", "status", "state"],
    "categories": ["tags", "categories", "kategorien", "labels", "schlagwörter"],
}

_DONE_WORDS = {"1", "x", "y", "yes", "ja", "true", "wahr", "done", "erledigt", "completed", "abgeschlossen"}


def _csv_priority(value: str) -> int:
    value = value.strip().casefold()
    if value in ("3", "high", "hoch", "!!!", "urgent", "dringend"):
        return 3
    if value in ("2", "medium", "mittel", "normal", "!!"):
        return 2 if value != "normal" else 0
    if value in ("1", "low", "niedrig", "!"):
        return 1
    return 0


def read_csv(text: str, default_list: str, today: date, tz: tzinfo, result: ImportResult) -> list[ImportedList]:
    """Any CSV with a header row; columns are found by name (see CSV_COLUMNS)."""
    rows = _read_csv(text)
    if not rows:
        return []
    headers = {header.strip().casefold(): header for header in rows[0] if header}
    columns = {
        key: next((headers[name] for name in names if name in headers), None) for key, names in CSV_COLUMNS.items()
    }
    if columns["title"] is None:
        raise ValueError("Keine Spalte für den Titel gefunden. Spalten in der Datei: " + ", ".join(rows[0]))
    lists: dict[str, ImportedList] = {}

    def cell(row: dict[str, str], key: str) -> str:
        return (row.get(columns[key]) or "").strip() if columns[key] else ""

    for row in rows:
        title = cell(row, "title")
        if not title:
            continue
        name = cell(row, "list") or default_list
        imported = lists.setdefault(name, ImportedList(key="csv:" + name.casefold(), name=name))
        fields, unknown = _due_from_text(cell(row, "due"), today, tz)
        if unknown:
            result.warnings.append(f"„{title}“: Fälligkeit „{unknown}“ nicht erkannt")
        imported.tasks.append(
            _task(
                title,
                "csv:" + _hash(name, title, cell(row, "due"), cell(row, "notes")),
                notes=cell(row, "notes"),
                completed=cell(row, "completed").casefold() in _DONE_WORDS,
                priority=_csv_priority(cell(row, "priority")),
                categories=[tag.strip() for tag in re.split(r"[,;]", cell(row, "categories")) if tag.strip()],
                **fields,
            )
        )
    return list(lists.values())


# -- iCalendar (VTODO) -----------------------------------------------------------------------------------------


def _ical_lines(text: str) -> list[tuple[str, dict[str, str], str]]:
    """Unfolded content lines as (name, parameters, value)."""
    unfolded = re.sub(r"\r?\n[ \t]", "", text)
    lines = []
    for line in unfolded.splitlines():
        if ":" not in line:
            continue
        head, value = line.split(":", 1)
        name, *params = head.split(";")
        parameters = dict(param.split("=", 1) for param in params if "=" in param)
        lines.append((name.upper(), {key.upper(): val for key, val in parameters.items()}, value))
    return lines


def _ical_text(value: str) -> str:
    return re.sub(r"\\([\\;,nN])", lambda m: "\n" if m[1] in "nN" else m[1], value).strip()


def _ical_moment(value: str, params: dict[str, str], tz: tzinfo) -> tuple[date, str | None] | None:
    """A DATE or DATE-TIME as local day and optional time."""
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        try:
            return datetime.strptime(value[:8], "%Y%m%d").date(), None
        except ValueError:
            return None
    try:
        moment = datetime.strptime(value.rstrip("Z"), "%Y%m%dT%H%M%S")
    except ValueError:
        return None
    if value.endswith("Z"):
        moment = moment.replace(tzinfo=timezone.utc).astimezone(tz)
    # Times with a TZID are taken as they are (normally the same zone as Home Assistant).
    return moment.date(), moment.strftime("%H:%M")


def read_ical(text: str, default_list: str, tz: tzinfo, result: ImportResult) -> list[ImportedList]:
    """VTODO entries of an .ics file (e.g. from Apple Reminders via CalDAV, Thunderbird, Nextcloud)."""
    lines = _ical_lines(text)
    name = next((_ical_text(value) for key, _, value in lines if key == "X-WR-CALNAME"), "") or default_list
    imported = ImportedList(key="ical:" + name.casefold(), name=name)
    todos: list[dict[str, tuple[dict[str, str], str]]] = []
    current: dict[str, Any] | None = None
    depth = 0
    for key, params, value in lines:
        if key == "BEGIN" and value.upper() == "VTODO":
            current, depth = {}, 0
        elif current is not None and key == "BEGIN":
            depth += 1
        elif current is not None and key == "END" and value.upper() == "VTODO":
            todos.append(current)
            current = None
        elif current is not None and key == "END":
            depth -= 1
        elif current is not None and depth == 0:
            current.setdefault(key, (params, value))
            if key == "CATEGORIES":
                current.setdefault("_categories", []).extend(_ical_text(part) for part in value.split(","))
    by_uid: dict[str, dict[str, Any]] = {}
    children = []
    for todo in todos:
        uid = todo.get("UID", ({}, ""))[1] or _hash(todo.get("SUMMARY", ({}, ""))[1])
        if "RELATED-TO" in todo:
            children.append(todo)
            continue
        task = _ical_task(todo, uid, tz, result)
        by_uid[uid] = task
        imported.tasks.append(task)
    for todo in children:
        if (parent := by_uid.get(todo["RELATED-TO"][1])) is not None:
            parent["steps"].append(
                {"title": _ical_text(todo.get("SUMMARY", ({}, ""))[1]), "completed": _ical_done(todo)}
            )
        else:
            uid = todo.get("UID", ({}, ""))[1]
            imported.tasks.append(_ical_task(todo, uid, tz, result))
    return [imported]


def _ical_done(todo: dict[str, Any]) -> bool:
    return todo.get("STATUS", ({}, ""))[1].upper() == "COMPLETED" or "COMPLETED" in todo


def _ical_task(todo: dict[str, Any], uid: str, tz: tzinfo, result: ImportResult) -> dict[str, Any]:
    title = _ical_text(todo.get("SUMMARY", ({}, ""))[1])
    fields: dict[str, Any] = {}
    if "DUE" in todo and (moment := _ical_moment(todo["DUE"][1], todo["DUE"][0], tz)):
        fields["due"] = Period.day(moment[0]).as_dict()
        if moment[1] and moment[1] != "00:00":
            fields["due_time"] = moment[1]
        if "RRULE" in todo:
            if recurrence := _rrule(todo["RRULE"][1]):
                fields["recurrence"] = recurrence
            else:
                result.warnings.append(f"„{title}“: Wiederholung nicht übernommen")
    raw_priority = todo.get("PRIORITY", ({}, "0"))[1].strip()
    priority = int(raw_priority) if raw_priority.isdigit() else 0
    completed = _ical_done(todo)
    completed_at = None
    if completed and "COMPLETED" in todo:
        if moment := _ical_moment(todo["COMPLETED"][1], todo["COMPLETED"][0], timezone.utc):
            completed_at = datetime.combine(moment[0], time.fromisoformat(moment[1] or "00:00"), timezone.utc).isoformat()
    return _task(
        title,
        "ical:" + uid,
        notes=_ical_text(todo.get("DESCRIPTION", ({}, ""))[1]),
        completed=completed,
        completed_at=completed_at,
        # 1–4 high, 5 medium, 6–9 low, 0 undefined.
        priority=3 if 1 <= priority <= 4 else 2 if priority == 5 else 1 if priority >= 6 else 0,
        categories=[item for item in todo.get("_categories", []) if item],
        **fields,
    )


# -- Detection and merging -------------------------------------------------------------------------------------


def detect_format(name: str, data: bytes) -> str:
    """Guess the format from the file name and its first bytes."""
    suffix = PurePath(name).suffix.lower()
    if suffix == ".zip":
        return "todoist"
    if suffix in (".ics", ".ical", ".ifb"):
        return "ical"
    head = _decode(data[:4096])
    if suffix == ".json" or head.lstrip().startswith("{"):
        return "google_tasks"
    if "BEGIN:VCALENDAR" in head:
        return "ical"
    if "Folder Name" in head and "List Name" in head:
        return "ticktick"
    first = head.lstrip("﻿").splitlines()[0] if head.strip() else ""
    if first.upper().startswith("TYPE") and "CONTENT" in first.upper():
        return "todoist"
    return "csv"


def read_export(name: str, data: bytes, fmt: str, default_list: str, today: date, tz: tzinfo, result: ImportResult) -> list[ImportedList]:
    """Read an export file of the given format ("auto" detects it)."""
    if fmt == "auto":
        fmt = detect_format(name, data)
    if fmt == "todoist":
        if PurePath(name).suffix.lower() == ".zip":
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                files = {
                    entry: _decode(archive.read(entry))
                    for entry in archive.namelist()
                    if entry.lower().endswith(".csv")
                }
        else:
            files = {name: _decode(data)}
        return read_todoist(files, today, tz, result)
    if fmt == "google_tasks":
        try:
            parsed = json.loads(_decode(data))
        except ValueError as err:
            raise ValueError(f"Datei ist kein gültiges JSON: {err}") from err
        if not isinstance(parsed, dict) or "items" not in parsed:
            raise ValueError("Keine Google-Tasks-Datei (Tasks.json aus Google Takeout erwartet)")
        return read_google_tasks(parsed, tz)
    if fmt == "ticktick":
        return read_ticktick(_decode(data), tz, result)
    if fmt == "csv":
        return read_csv(_decode(data), default_list, today, tz, result)
    if fmt == "ical":
        return read_ical(_decode(data), default_list, tz, result)
    raise ValueError(f"Unbekanntes Format: {fmt}")


def merge_lists(
    collection: TaskCollection,
    lists: list[ImportedList],
    result: ImportResult,
    *,
    include_completed: bool,
    target_list: str | None = None,
    dry_run: bool,
) -> ImportResult:
    """Add imported lists and tasks. `target_list` puts everything into one list (by name)."""
    by_name = {item.name.casefold(): item for item in collection.lists.values()}
    for imported in lists:
        name = target_list or imported.name
        target = (None if target_list else collection.find_external_list(imported.key)) or by_name.get(name.casefold())
        if target is None:
            if name not in result.lists_created:
                result.lists_created.append(name)
            if not dry_run:
                target = collection.create_list(
                    name, external_id=None if target_list else imported.key, group=imported.group
                )
                by_name[name.casefold()] = target
        elif name not in result.lists_merged and name not in result.lists_created:
            result.lists_merged.append(name)

        # Each new task goes on top, so add them bottom first to keep the order of the export.
        for fields in reversed(imported.tasks):
            if collection.find_external(fields["external_id"]):
                result.tasks_skipped_existing += 1
                continue
            if fields["completed"] and not include_completed:
                result.tasks_skipped_completed += 1
                continue
            result.tasks_imported += 1
            result.tasks_completed += fields["completed"]
            if dry_run or target is None:
                continue
            task = Task.from_dict({**fields, "id": new_id(), "list_id": target.id})
            task.position = collection.top_position(target.id)
            collection.add_task(task)
    return result
