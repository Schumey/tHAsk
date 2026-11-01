from datetime import date

import yaml

from core.assist import LANGUAGES, added_answer, due_answer, due_tasks, sentences, split_list
from core.models import Task, TaskList
from core.period import Granularity, Period

TODAY = date(2026, 11, 4)  # Wednesday, week 45


def _tasks() -> list[Task]:
    return [
        Task(id="1", list_id="l", title="Steuer", due=Period.day(TODAY)),
        Task(id="2", list_id="l", title="Alt", due=Period.day(date(2026, 11, 2))),
        Task(id="3", list_id="l", title="Woche", due=Period(Granularity.WEEK, TODAY)),
        Task(id="4", list_id="l", title="Monat", due=Period(Granularity.MONTH, TODAY)),
        Task(id="5", list_id="l", title="Fertig", due=Period.day(TODAY), completed=True),
        Task(id="6", list_id="l", title="Ohne"),
    ]


def _titles(tasks: list[Task]) -> list[str]:
    return [task.title for task in tasks]


def test_due_tasks_include_overdue_and_skip_completed() -> None:
    assert _titles(due_tasks(_tasks(), "today", TODAY)) == ["Alt", "Steuer"]
    assert _titles(due_tasks(_tasks(), "this_week", TODAY)) == ["Alt", "Steuer", "Woche"]
    assert _titles(due_tasks(_tasks(), "this_month", TODAY)) == ["Alt", "Steuer", "Woche", "Monat"]
    assert _titles(due_tasks(_tasks(), "overdue", TODAY)) == ["Alt"]


def test_due_tasks_rolling_week() -> None:
    next_tuesday = Task(id="7", list_id="l", title="Dienstag", due=Period.day(date(2026, 11, 10)))
    assert "Dienstag" not in _titles(due_tasks([next_tuesday], "this_week", TODAY))
    assert _titles(due_tasks([next_tuesday], "this_week", TODAY, rolling=True)) == ["Dienstag"]


def test_due_answer_german() -> None:
    tasks = due_tasks(_tasks(), "this_week", TODAY)
    assert due_answer("de", "this_week", tasks) == "Diese Woche sind 3 Aufgaben fällig: Alt, Steuer und Woche."
    assert due_answer("de-DE", "today", tasks[:1]) == "Heute ist eine Aufgabe fällig: Alt."
    assert due_answer("de", "today", []) == "Heute ist nichts fällig."
    assert due_answer("de", "overdue", []) == "Nichts ist überfällig."


def test_due_answer_counts_the_rest() -> None:
    many = [Task(id=str(i), list_id="l", title=f"T{i}", due=Period.day(TODAY)) for i in range(7)]
    assert due_answer("en", "today", many) == "7 tasks are due today: T0, T1, T2, T3, T4 and 2 more."
    # Unknown languages answer in English.
    assert due_answer("fr", "overdue", many[:1]) == "One task is overdue: T0."


def test_added_answer() -> None:
    assert added_answer("de", "Steuer", "Aufgaben", "KW 47") == "Steuer steht auf Aufgaben, fällig KW 47."
    assert added_answer("en", "Taxes", "Tasks", None) == "Added Taxes to Tasks."


def test_split_list_only_for_existing_lists() -> None:
    lists = [TaskList(id="a", name="Einkauf"), TaskList(id="b", name="Büro")]
    assert split_list("de", "Milch auf die Einkaufsliste", lists) == ("Milch auf die Einkaufsliste", None)
    text, found = split_list("de", "Milch auf die Liste Einkauf", lists)
    assert (text, found.id) == ("Milch", "a")
    text, found = split_list("de", "Brot zu Oma bringen auf Einkauf", lists)
    assert (text, found.id) == ("Brot zu Oma bringen", "a")
    text, found = split_list("de", "Bericht KW 47 in meine büro liste", lists)
    assert (text, found.id) == ("Bericht KW 47", "b")
    text, found = split_list("en", "milk to my Einkauf list", lists)
    assert (text, found.id) == ("milk", "a")
    assert split_list("de", "Steuer zu Ende machen", lists) == ("Steuer zu Ende machen", None)


def test_sentences_are_valid_yaml() -> None:
    for lang in LANGUAGES:
        content = yaml.safe_load(sentences(lang))
        assert content["language"] == lang
        assert set(content["intents"]) == {"ThaskDueTasks", "ThaskAddTask"}
        periods = {value["out"] for value in content["lists"]["thask_period"]["values"]}
        assert periods == {"today", "this_week", "this_month"}
