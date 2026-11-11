"""Import of checklist files (JSON and CSV with external_id): mapping, duplicates, validation, all-or-nothing."""

from datetime import date, timedelta, timezone
import json
from pathlib import Path

import pytest

from core.collection import TaskCollection
from core.importers import detect_format, import_file
from core.period import Granularity

CET = timezone(timedelta(hours=1))
TODAY = date(2026, 11, 11)
SAMPLES = [Path(__file__).parents[1] / "samples", Path(__file__).parents[2] / "tHAsk-local"]


def checklist() -> dict:
    return {
        "schema_version": 1,
        "source": "Test",
        "language": "de",
        "lists": [
            {
                "id": "vorbereitung",
                "title": "Reisevorbereitung",
                "groups": [
                    {
                        "title": "Dinge mit Vorlaufzeit (bis 15.11.)",
                        "description": "Früh erledigen.",
                        "items": [
                            {
                                "external_id": "c-pass",
                                "title": "Reisepass prüfen",
                                "notes": "Gültig bis August 2027 · 2 freie Seiten.",
                                "due": "2026-11-15",
                                "date_label": "",
                                "tags": ["Papiere"],
                                "done": False,
                            },
                            {
                                "external_id": "c-karte",
                                "title": "Kreditkarte ohne Auslandsgebühr",
                                "notes": "",
                                "due": None,
                                "date_label": "",
                                "tags": [],
                                "done": False,
                            },
                        ],
                    }
                ],
            },
            {
                "id": "fluege",
                "title": "Flüge und Transfers",
                "groups": [
                    {
                        "title": "Hinflug",
                        "description": "",
                        "items": [
                            {
                                "external_id": "f-hin",
                                "title": "Flug nach Peking",
                                "notes": "Sitzplatz wählen.",
                                "due": "2026-12-07",
                                "date_label": "7.12. · ca. 10 Std.",
                                "tags": ["Flug", "Tickets"],
                                "done": True,
                            }
                        ],
                    }
                ],
            },
        ],
    }


def as_bytes(data: dict) -> bytes:
    return json.dumps(data, ensure_ascii=False).encode("utf-8")


def run(collection: TaskCollection, data: bytes, name: str = "reise.json", *, dry_run: bool = False, **kwargs):
    return import_file(collection, name, data, today=TODAY, tz=CET, dry_run=dry_run, **kwargs)


def csv_bytes(rows: list[str], header: str = "external_id;list;group;title;notes;due;date_label;tags;done") -> bytes:
    return ("﻿" + "\r\n".join([header, *rows]) + "\r\n").encode("utf-8")


def test_json_creates_lists_and_tasks():
    collection = TaskCollection()
    result = run(collection, as_bytes(checklist()))
    assert result.errors == []
    assert result.lists_created == ["Reisevorbereitung", "Flüge und Transfers"]
    assert result.sections == 2
    assert (result.tasks_imported, result.tasks_skipped_existing) == (3, 0)
    assert len(collection.lists) == 2
    assert len(collection.tasks) == 3


def test_mapping_of_fields():
    collection = TaskCollection()
    run(collection, as_bytes(checklist()))
    by_ext = {task.external_id: task for task in collection.tasks.values()}
    passport = by_ext["checklist:c-pass"]
    assert passport.title == "Reisepass prüfen"
    assert passport.due.granularity is Granularity.DAY and passport.due.start == date(2026, 11, 15)
    assert passport.categories == ["Papiere", "Dinge mit Vorlaufzeit (bis 15.11.)"]
    # The note of the section goes on its first item only.
    assert passport.notes == "Gültig bis August 2027 · 2 freie Seiten.\nHinweis zum Abschnitt „Dinge mit Vorlaufzeit (bis 15.11.)“: Früh erledigen."
    assert "Hinweis" not in by_ext["checklist:c-karte"].notes
    assert by_ext["checklist:c-karte"].due is None
    flight = by_ext["checklist:f-hin"]
    # The date label comes first in the note.
    assert flight.notes == "7.12. · ca. 10 Std.\nSitzplatz wählen."
    assert flight.categories == ["Flug", "Tickets", "Hinflug"]
    assert collection.find_external_list("checklist:fluege").name == "Flüge und Transfers"


def test_done_is_never_imported():
    collection = TaskCollection()
    run(collection, as_bytes(checklist()))
    assert not any(task.completed for task in collection.tasks.values())


def test_order_of_the_file_is_kept():
    collection = TaskCollection()
    run(collection, as_bytes(checklist()))
    rows = collection.tasks_in(collection.find_external_list("checklist:vorbereitung").id)
    assert [task.title for task in rows] == ["Reisepass prüfen", "Kreditkarte ohne Auslandsgebühr"]


def test_dry_run_changes_nothing():
    collection = TaskCollection()
    result = run(collection, as_bytes(checklist()), dry_run=True)
    assert result.dry_run and result.tasks_imported == 3 and result.lists_created
    assert not collection.lists and not collection.tasks


def test_second_import_creates_nothing_new():
    collection = TaskCollection()
    run(collection, as_bytes(checklist()))
    again = run(collection, as_bytes(checklist()))
    assert (again.tasks_imported, again.tasks_skipped_existing) == (0, 3)
    assert again.lists_created == [] and again.lists_merged == ["Reisevorbereitung", "Flüge und Transfers"]
    assert len(collection.lists) == 2 and len(collection.tasks) == 3


def test_completed_task_stays_completed_and_is_not_changed():
    collection = TaskCollection()
    run(collection, as_bytes(checklist()))
    task = collection.find_external("checklist:c-pass")
    collection.update_task(task.id, {"completed": True, "notes": "Meine Notiz"}, TODAY)
    changed = checklist()
    changed["lists"][0]["groups"][0]["items"][0].update(title="Neuer Titel", due="2027-01-01", done=False)
    run(collection, as_bytes(changed))
    task = collection.find_external("checklist:c-pass")
    assert task.completed and task.completed_at
    assert (task.title, task.notes, task.due.start) == ("Reisepass prüfen", "Meine Notiz", date(2026, 11, 15))


def test_existing_tasks_and_lists_are_kept():
    collection = TaskCollection()
    mine = collection.create_list("Reisevorbereitung")
    own = collection.create_task(mine.id, "Eigene Aufgabe")
    run(collection, as_bytes(checklist()))
    assert collection.get_task(own.id).title == "Eigene Aufgabe"
    # The list with the same name is reused, not duplicated.
    assert [item.name for item in collection.lists.values()].count("Reisevorbereitung") == 1
    assert len(collection.tasks_in(mine.id)) == 3


def test_csv_with_bom_and_umlauts():
    rows = [
        'c-pass;Reisevorbereitung;Dinge mit Vorlaufzeit;Reisepass prüfen;"Gültig, bis August; 2 Seiten.";2026-11-15;;Papiere,Gesundheit;false',
        "f-hin;Flüge und Transfers;Hinflug;Flug nach Peking;;;7.12. · ca. 10 Std.;;true",
    ]
    data = csv_bytes(rows)
    assert detect_format("reise.csv", data) == "checklist"
    collection = TaskCollection()
    result = run(collection, data, "reise.csv")
    assert result.errors == [] and result.tasks_imported == 2 and result.sections == 2
    passport = collection.find_external("checklist:c-pass")
    assert passport.notes == "Gültig, bis August; 2 Seiten."
    assert passport.categories == ["Papiere", "Gesundheit", "Dinge mit Vorlaufzeit"]
    assert passport.due.start == date(2026, 11, 15)
    flight = collection.find_external("checklist:f-hin")
    assert flight.notes == "7.12. · ca. 10 Std." and not flight.completed
    assert {item.name for item in collection.lists.values()} == {"Reisevorbereitung", "Flüge und Transfers"}


def test_json_then_csv_adds_nothing():
    collection = TaskCollection()
    run(collection, as_bytes(checklist()))
    data = csv_bytes(["c-pass;Reisevorbereitung;Abschnitt;Reisepass prüfen;;;;;false"])
    result = run(collection, data, "reise.csv")
    assert (result.tasks_imported, result.tasks_skipped_existing) == (0, 1)
    assert len(collection.lists) == 2


def test_format_detection():
    assert detect_format("x.json", as_bytes(checklist())) == "checklist"
    assert detect_format("Tasks.json", b'{"kind": "tasks#taskLists", "items": []}') == "google_tasks"
    assert detect_format("x.csv", csv_bytes([])) == "checklist"
    assert detect_format("x.csv", b"title,due\nA,2026-11-11\n") == "csv"


# -- validation ---------------------------------------------------------------------------------


def broken() -> dict:
    data = checklist()
    items = data["lists"][0]["groups"][0]["items"]
    items.append({"external_id": "c-ohne-titel", "title": "  ", "due": None})
    items.append({"external_id": "c-datum", "title": "Kaputtes Datum", "due": "2026-02-30"})
    items.append({"external_id": "c-format", "title": "Falsches Format", "due": "15.11.2026"})
    items.append({"external_id": "c-pass", "title": "Doppelte ID", "due": None})
    items.append({"title": "Ohne ID"})
    items.append({"external_id": "c-tags", "title": "Tags kaputt", "tags": "Papiere", "notes": 5})
    items.append("kein Objekt")
    return data


def test_invalid_items_are_reported_and_do_not_stop_the_rest():
    collection = TaskCollection()
    result = run(collection, as_bytes(broken()))
    assert result.tasks_imported == 3
    errors = "\n".join(result.errors)
    assert "Pflichtfeld „title“ fehlt" in errors
    assert "Datum „2026-02-30“ gibt es nicht" in errors
    assert "Datum „15.11.2026“ hat das falsche Format (erwartet JJJJ-MM-TT)" in errors
    assert "external_id „c-pass“ kommt in der Datei mehrfach vor" in errors
    assert "Pflichtfeld „external_id“ fehlt" in errors
    assert "Feld „notes“ muss Text sein" in errors
    assert "Eintrag ist keine Aufgabe" in errors
    assert len(result.errors) == 7
    assert {task.external_id for task in collection.tasks.values()} == {
        "checklist:c-pass", "checklist:c-karte", "checklist:f-hin",
    }
    # Where the error is: list, section, number of the item.
    assert "Liste „Reisevorbereitung“, Abschnitt „Dinge mit Vorlaufzeit (bis 15.11.)“, Aufgabe 3" in errors


def test_unknown_schema_version_is_refused():
    data = checklist()
    data["schema_version"] = 2
    with pytest.raises(ValueError, match="Unbekannte schema_version 2"):
        run(TaskCollection(), as_bytes(data))
    del data["schema_version"]
    with pytest.raises(ValueError, match="Unbekannte schema_version None"):
        run(TaskCollection(), as_bytes(data), fmt="checklist")


def test_unreadable_files_are_refused():
    collection = TaskCollection()
    with pytest.raises(ValueError, match="kein gültiges JSON"):
        run(collection, b'{"schema_version": 1,', fmt="checklist")
    with pytest.raises(ValueError, match="Feld „lists“ fehlt"):
        run(collection, b'{"schema_version": 1}', fmt="checklist")
    with pytest.raises(ValueError, match="Spalten fehlen in der Kopfzeile: list, title"):
        run(collection, csv_bytes([], "external_id;gruppe"), "x.csv", fmt="checklist")
    with pytest.raises(ValueError, match="nicht UTF-8"):
        run(collection, "Prüfen".encode("cp1252"), "x.csv", fmt="checklist")
    assert not collection.lists and not collection.tasks


def test_csv_errors_name_the_row():
    data = csv_bytes(
        [
            "a;Liste;Abschnitt;Gut;;2026-11-15;;;false",
            "b;Liste;Abschnitt;;;;;;false",
            "c;Liste;Abschnitt;Datum;;morgen;;;false",
            ";;;Ohne Liste;;;;;false",
        ]
    )
    result = run(TaskCollection(), data, "x.csv")
    assert result.tasks_imported == 1
    assert [error.split(":")[0] for error in result.errors] == ["Zeile 3", "Zeile 4 („Datum“)", "Zeile 5"]


def test_all_or_nothing_when_saving_fails(monkeypatch):
    collection = TaskCollection()
    existing = collection.create_list("Vorhanden")
    collection.create_task(existing.id, "Bleibt")
    before = collection.dump()
    original = collection.add_task
    calls = []

    def failing(task):
        calls.append(task.id)
        if len(calls) == 3:
            raise RuntimeError("Speichern fehlgeschlagen")
        return original(task)

    monkeypatch.setattr(collection, "add_task", failing)
    with pytest.raises(RuntimeError):
        run(collection, as_bytes(checklist()))
    assert collection.dump() == before


# -- the real files, if they are at hand (private travel data, not part of the repository) ------------------


def _sample(name: str) -> bytes:
    for folder in SAMPLES:
        if (folder / name).is_file():
            return (folder / name).read_bytes()
    pytest.skip(f"{name} nicht vorhanden")


def test_sample_json_imports_3_lists_and_57_tasks():
    data = _sample("reise-checklisten.json")
    collection = TaskCollection()
    result = run(collection, data)
    assert result.errors == []
    assert (len(collection.lists), len(collection.tasks)) == (3, 57)
    # All dates exactly as in the file, notes and tags carried over, nothing ticked.
    source = json.loads(data)
    items = {
        f"checklist:{item['external_id']}": item
        for task_list in source["lists"]
        for group in task_list["groups"]
        for item in group["items"]
    }
    assert len(items) == 57
    for task in collection.tasks.values():
        item = items[task.external_id]
        assert task.title == item["title"]
        assert (task.due.start.isoformat() if task.due else None) == item["due"]
        assert set(item["tags"]) <= set(task.categories)
        assert item["notes"] in task.notes and item["date_label"] in task.notes
        assert not task.completed
    again = run(collection, data)
    assert (again.tasks_imported, again.tasks_skipped_existing) == (0, 57)
    assert len(collection.tasks) == 57


def test_sample_csv_matches_json():
    collection = TaskCollection()
    run(collection, _sample("reise-checklisten.json"))
    result = run(collection, _sample("reise-checklisten.csv"), "reise-checklisten.csv")
    assert result.errors == []
    assert (result.tasks_imported, result.tasks_skipped_existing) == (0, 57)
    fresh = TaskCollection()
    run(fresh, _sample("reise-checklisten.csv"), "reise-checklisten.csv")
    assert (len(fresh.lists), len(fresh.tasks)) == (3, 57)
    assert {list_.name for list_ in fresh.lists.values()} == {"Reisevorbereitung", "Flüge und Transfers", "Hotels"}
