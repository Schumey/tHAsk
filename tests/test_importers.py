from datetime import date, timedelta, timezone
import io
import json
import zipfile

import pytest

from core.collection import TaskCollection
from core.importers import detect_format, merge_lists, read_export
from core.ms_todo import ImportResult

CET = timezone(timedelta(hours=1))
TODAY = date(2026, 11, 2)

TODOIST = """TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE,DATE_LANG,TIMEZONE
task,Steuer abgeben @büro,Belege sammeln,1,1,Me,,2026-11-30,de,Europe/Berlin
task,Belege scannen,,4,2,Me,,,de,Europe/Berlin
note,Ordner im Keller,,,,Me,,,,
,,,,,,,,,
section,Haushalt,,,,,,,,
task,Fenster putzen,,4,1,Me,,KW 47,de,Europe/Berlin
task,Blumen gießen,,3,1,Me,,every day,en,Europe/Berlin
"""

GOOGLE = {
    "kind": "tasks#taskLists",
    "items": [
        {
            "kind": "tasks#tasks",
            "id": "L1",
            "title": "Einkauf",
            "items": [
                {"id": "a", "title": "Milch", "status": "needsAction", "position": "001", "due": "2026-11-05T00:00:00.000Z"},
                {"id": "b", "title": "Brot", "status": "completed", "position": "000", "completed": "2026-11-01T10:00:00.000Z"},
                {"id": "c", "title": "laktosefrei", "status": "needsAction", "parent": "a", "position": "000"},
                {"id": "d", "title": "gelöscht", "status": "needsAction", "deleted": True},
            ],
        }
    ],
}

TICKTICK = '''"Date: 2026-11-01+0000"
"Version: 7.1"
"Status:
0 Normal
1 Completed
2 Archived"
"Folder Name","List Name","Title","Kind","Tags","Content","Is Check list","Start Date","Due Date","Reminder","Repeat","Priority","Status","Created Time","Completed Time","Order","Timezone","Is All Day","Is Floating","Column Name","Column Order","View Mode","taskId","parentId"
"Privat","Garten","Rasen mähen","TEXT","draußen","Vorher tanken","N","","2026-11-07T23:00:00+0000","","FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH","5","0","2026-10-01T08:00:00+0000","","-2","Europe/Berlin","true","false","","","list","t1",""
"Privat","Garten","Hecke","CHECKLIST","","▫schneiden
▪Werkzeug holen","Y","","2026-11-03T14:30:00+0000","","","3","0","2026-10-01T08:00:00+0000","","-1","Europe/Berlin","false","false","","","list","t2",""
"Privat","Garten","Unteraufgabe","TEXT","","","N","","","","","0","1","2026-10-01T08:00:00+0000","2026-10-02T08:00:00+0000","0","Europe/Berlin","false","false","","","list","t3","t1"
"","Inbox","Erledigt","TEXT","","","N","","","","","1","2","2026-10-01T08:00:00+0000","2026-10-02T08:00:00+0000","0","Europe/Berlin","false","false","","","list","t4",""
'''

ICAL = """BEGIN:VCALENDAR
VERSION:2.0
X-WR-CALNAME:Erinnerungen
BEGIN:VTODO
UID:u1
SUMMARY:Arzt anrufen\\, dringend
DESCRIPTION:Nummer im Handy\\nab 8 Uhr
DUE;VALUE=DATE:20261104
PRIORITY:1
CATEGORIES:Gesundheit,Telefon
RRULE:FREQ=MONTHLY;INTERVAL=1
BEGIN:VALARM
TRIGGER:-PT15M
SUMMARY:nicht dies
END:VALARM
END:VTODO
BEGIN:VTODO
UID:u2
SUMMARY:Rezept holen
RELATED-TO:u1
STATUS:COMPLETED
END:VTODO
BEGIN:VTODO
UID:u3
SUMMARY:Lange Zeile die umgebrochen
  wurde
DUE:20261105T090000Z
STATUS:COMPLETED
COMPLETED:20261101T120000Z
END:VTODO
END:VCALENDAR
"""

CSV = """Titel;Liste;Fällig;Priorität;Erledigt;Notizen
Auto waschen;Haushalt;31.12.2026;hoch;;
Reifen wechseln;Auto;November;;;Winterreifen
Alt;Haushalt;2026-10-01;;ja;
Ohne Liste;;;niedrig;;
"""


def read(name, data, fmt="auto", default_list="Import"):
    result = ImportResult(dry_run=False)
    if isinstance(data, str):
        data = data.encode("utf-8")
    return read_export(name, data, fmt, default_list, TODAY, CET, result), result


def by_title(lists):
    return {task["title"]: task for imported in lists for task in imported.tasks}


def test_detect_format():
    assert detect_format("x.zip", b"") == "todoist"
    assert detect_format("Tasks.json", b"{}") == "google_tasks"
    assert detect_format("x.ics", b"") == "ical"
    assert detect_format("backup.csv", TICKTICK.encode()) == "ticktick"
    assert detect_format("Projekt.csv", TODOIST.encode()) == "todoist"
    assert detect_format("liste.csv", CSV.encode()) == "csv"


def test_todoist():
    lists, result = read("Steuern [2203306141].csv", TODOIST)
    assert [item.name for item in lists] == ["Steuern"]
    tasks = by_title(lists)
    assert list(tasks) == ["Steuer abgeben", "Fenster putzen", "Blumen gießen"]
    tax = tasks["Steuer abgeben"]
    assert tax["priority"] == 3
    assert tax["due"] == {"granularity": "day", "start": "2026-11-30"}
    assert tax["categories"] == ["büro"]
    assert tax["steps"] == [{"title": "Belege scannen", "completed": False}]
    assert tax["notes"] == "Belege sammeln\n\nOrdner im Keller"
    windows = tasks["Fenster putzen"]
    assert windows["due"]["granularity"] == "week"
    assert windows["categories"] == ["Haushalt"]
    flowers = tasks["Blumen gießen"]
    assert flowers["priority"] == 1
    # Todoist's natural-language dates go through the quick entry parser.
    assert flowers["recurrence"] == {"unit": "day", "interval": 1}
    assert not result.warnings


def test_todoist_backup_zip():
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("Steuern [1].csv", TODOIST)
        archive.writestr("Inbox [2].csv", "TYPE,CONTENT,PRIORITY,INDENT,DATE\ntask,Anrufen,4,1,\n")
    lists, _ = read("todoist-backup.zip", buffer.getvalue())
    assert sorted(item.name for item in lists) == ["Inbox", "Steuern"]


def test_google_tasks():
    lists, _ = read("Tasks.json", json.dumps(GOOGLE))
    assert lists[0].name == "Einkauf"
    tasks = by_title(lists)
    assert list(tasks) == ["Brot", "Milch"]
    assert tasks["Milch"]["due"] == {"granularity": "day", "start": "2026-11-05"}
    assert tasks["Milch"]["steps"] == [{"title": "laktosefrei", "completed": False}]
    assert tasks["Brot"]["completed"] and tasks["Brot"]["completed_at"].startswith("2026-11-01T10:00")


def test_ticktick():
    lists, result = read("backup.csv", TICKTICK)
    garden = next(item for item in lists if item.name == "Garten")
    assert garden.group == "Privat"
    assert [task["title"] for task in garden.tasks] == ["Rasen mähen", "Hecke"]
    lawn, hedge = garden.tasks
    assert lawn["priority"] == 3
    # All-day due date at 23:00 UTC is the next day in Berlin.
    assert lawn["due"] == {"granularity": "day", "start": "2026-11-08"}
    assert "due_time" not in lawn
    assert lawn["recurrence"] == {"unit": "week", "interval": 2, "weekdays": [0, 3]}
    assert lawn["categories"] == ["draußen"]
    assert lawn["steps"] == [{"title": "Unteraufgabe", "completed": True}]
    assert hedge["priority"] == 2
    assert hedge["due_time"] == "15:30"
    assert hedge["steps"] == [{"title": "schneiden", "completed": False}, {"title": "Werkzeug holen", "completed": True}]
    inbox = next(item for item in lists if item.name == "Inbox")
    assert inbox.tasks[0]["completed"] and inbox.tasks[0]["priority"] == 1
    assert not result.warnings


def test_ical():
    lists, _ = read("export.ics", ICAL)
    assert lists[0].name == "Erinnerungen"
    tasks = by_title(lists)
    call = tasks["Arzt anrufen, dringend"]
    assert call["notes"] == "Nummer im Handy\nab 8 Uhr"
    assert call["due"] == {"granularity": "day", "start": "2026-11-04"}
    assert call["priority"] == 3
    assert call["categories"] == ["Gesundheit", "Telefon"]
    assert call["recurrence"] == {"unit": "month", "interval": 1}
    assert call["steps"] == [{"title": "Rezept holen", "completed": True}]
    folded = tasks["Lange Zeile die umgebrochen wurde"]
    assert folded["due_time"] == "10:00"
    assert folded["completed"] and folded["completed_at"].startswith("2026-11-01T12:00")


def test_generic_csv():
    lists, result = read("liste.csv", CSV, default_list="Import")
    assert sorted(item.name for item in lists) == ["Auto", "Haushalt", "Import"]
    tasks = by_title(lists)
    assert tasks["Auto waschen"]["due"] == {"granularity": "day", "start": "2026-12-31"}
    assert tasks["Auto waschen"]["priority"] == 3
    assert tasks["Reifen wechseln"]["due"]["granularity"] == "month"
    assert tasks["Reifen wechseln"]["notes"] == "Winterreifen"
    assert tasks["Alt"]["completed"]
    assert tasks["Ohne Liste"]["priority"] == 1
    assert not result.warnings


def test_csv_without_title_column():
    with pytest.raises(ValueError, match="Titel"):
        read("x.csv", "Foo,Bar\n1,2\n", fmt="csv")


def test_merge_is_idempotent_and_keeps_order():
    collection = TaskCollection()
    existing = collection.create_list("Haushalt")
    lists, _ = read("liste.csv", CSV)

    dry = merge_lists(collection, lists, ImportResult(dry_run=True), include_completed=True, dry_run=True)
    assert dry.tasks_imported == 4 and not collection.tasks
    assert dry.lists_merged == ["Haushalt"] and sorted(dry.lists_created) == ["Auto", "Import"]

    first = merge_lists(collection, lists, ImportResult(dry_run=False), include_completed=False, dry_run=False)
    assert first.tasks_imported == 3 and first.tasks_skipped_completed == 1
    titles = [task.title for task in collection.tasks_in(existing.id)]
    assert titles == ["Auto waschen"]

    again = merge_lists(collection, lists, ImportResult(dry_run=False), include_completed=True, dry_run=False)
    assert again.tasks_skipped_existing == 3 and again.tasks_imported == 1


def test_merge_into_one_list_and_group():
    collection = TaskCollection()
    lists, _ = read("backup.csv", TICKTICK)
    merge_lists(collection, lists, ImportResult(dry_run=False), include_completed=True, dry_run=False)
    garden = next(item for item in collection.lists.values() if item.name == "Garten")
    assert garden.group == "Privat"
    assert [task.title for task in collection.tasks_in(garden.id)] == ["Rasen mähen", "Hecke"]

    other = TaskCollection()
    merge_lists(other, lists, ImportResult(dry_run=False), include_completed=True, target_list="TickTick", dry_run=False)
    assert [item.name for item in other.lists.values()] == ["TickTick"]
    assert len(other.tasks) == 3
