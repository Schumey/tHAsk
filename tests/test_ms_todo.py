from datetime import date, timedelta, timezone

import pytest

from core.collection import TaskCollection
from core.ms_todo import ImportOptions, import_export
from core.period import Granularity, Period

# Central European winter time, like a Home Assistant set to Europe/Berlin.
CET = timezone(timedelta(hours=1))


def graph_task(task_id, title, **fields):
    return {
        "id": task_id,
        "title": title,
        "importance": "normal",
        "status": "notStarted",
        "isReminderOn": False,
        "createdDateTime": f"2026-10-{10 + len(task_id):02d}T08:00:00.1234567Z",
        "lastModifiedDateTime": "2026-10-20T08:00:00Z",
        "body": {"content": "", "contentType": "text"},
        **fields,
    }


def due(day_utc):
    return {"dateTime": f"{day_utc}.0000000", "timeZone": "UTC"}


@pytest.fixture
def export():
    return {
        "source": "ms_todo",
        "lists": [
            {
                "id": "AAMk=list1",
                "displayName": "Aufgaben",
                "wellknownListName": "defaultList",
                "tasks": [
                    graph_task(
                        "t1",
                        "Steuer",
                        importance="high",
                        # Local midnight of 30 Nov, stored as UTC.
                        dueDateTime=due("2026-11-29T23:00:00"),
                        body={"content": "<p>Belege &amp; Quittungen</p>", "contentType": "html"},
                        checklistItems=[{"displayName": "Belege", "isChecked": True}],
                        recurrence={"pattern": {"type": "absoluteMonthly", "interval": 1}},
                    ),
                    graph_task("t22", "Rasen mähen", dueDateTime=due("2026-11-08T00:00:00")),
                    graph_task(
                        "t333",
                        "Erledigt",
                        status="completed",
                        completedDateTime={"dateTime": "2026-10-25T10:00:00.0000000", "timeZone": "UTC"},
                    ),
                    graph_task(
                        "t4444",
                        "Erinnerung",
                        isReminderOn=True,
                        reminderDateTime={"dateTime": "2026-11-05T07:30:00.0000000", "timeZone": "UTC"},
                        hasAttachments=True,
                    ),
                ],
            },
            {"id": "flagged", "displayName": "Gekennzeichnete E-Mail", "wellknownListName": "flaggedEmails",
             "tasks": [graph_task("m1", "Mail")]},
            {"id": "list2", "displayName": "Einkauf", "wellknownListName": "none", "tasks": []},
        ],
    }


@pytest.fixture
def collection():
    collection = TaskCollection()
    collection.create_list("Aufgaben")
    return collection


def by_title(collection):
    return {task.title: task for task in collection.tasks.values()}


def test_dry_run_changes_nothing(collection, export):
    before = collection.dump()
    result = import_export(collection, export, ImportOptions(), CET, dry_run=True)
    assert collection.dump() == before
    assert result.lists_merged == ["Aufgaben"]
    assert result.lists_created == ["Einkauf"]
    assert result.tasks_imported == 4
    assert result.tasks_completed == 1
    assert (result.month_end_candidates, result.sunday_candidates) == (1, 1)


def test_import_converts_fields(collection, export):
    result = import_export(collection, export, ImportOptions(), CET, dry_run=False)
    tasks = by_title(collection)
    assert "Mail" not in tasks
    steuer = tasks["Steuer"]
    assert steuer.due == Period.day(date(2026, 11, 30))
    assert steuer.important
    assert steuer.notes == "Belege & Quittungen"
    assert [(step.title, step.completed) for step in steuer.steps] == [("Belege", True)]
    assert steuer.recurrence.unit is Granularity.MONTH
    assert steuer.external_id == "ms_todo:t1"
    assert steuer.created.startswith("2026-10-12T08:00:00.123456")
    # Midnight UTC is 01:00 local, still the same day.
    assert tasks["Rasen mähen"].due == Period.day(date(2026, 11, 8))
    assert tasks["Erledigt"].completed and tasks["Erledigt"].completed_at.startswith("2026-10-25T10:00")
    assert tasks["Erinnerung"].reminder == "2026-11-05T07:30:00+00:00"
    assert any("Anhänge" in warning for warning in result.warnings)
    # Newest first, as in To Do.
    default = collection.default_list().id
    assert [task.title for task in collection.tasks_in(default)][0] == "Erinnerung"
    assert {item.name for item in collection.lists.values()} == {"Aufgaben", "Einkauf"}


def test_fuzzy_conversion(collection, export):
    options = ImportOptions(convert_month_ends=True, convert_sundays=True)
    result = import_export(collection, export, options, CET, dry_run=False)
    tasks = by_title(collection)
    assert tasks["Steuer"].due == Period.month(2026, 11)
    assert tasks["Rasen mähen"].due == Period.iso_week(2026, 45)
    assert (result.converted_to_month, result.converted_to_week) == (1, 1)


def test_reimport_skips_existing(collection, export):
    import_export(collection, export, ImportOptions(), CET, dry_run=False)
    count = len(collection.tasks)
    result = import_export(collection, export, ImportOptions(), CET, dry_run=False)
    assert len(collection.tasks) == count
    assert result.tasks_skipped_existing == 4
    assert result.lists_created == []


def test_skip_completed(collection, export):
    result = import_export(collection, export, ImportOptions(include_completed=False), CET, dry_run=False)
    assert "Erledigt" not in by_title(collection)
    assert result.tasks_skipped_completed == 1


def test_rejects_other_files(collection):
    with pytest.raises(ValueError):
        import_export(collection, {"lists": []}, ImportOptions(), CET, dry_run=True)
