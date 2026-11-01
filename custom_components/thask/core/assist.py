"""Assist (voice): which tasks are due, adding tasks by voice, and the sentences Assist listens to.

Home Assistant only matches sentences from files under `config/custom_sentences/<language>/`, which an integration
cannot ship. `sentences()` builds that file; the service `thask.install_sentences` writes it.
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import date
import re

from .models import Task, TaskList, this_week_range
from .period import Granularity, Period

INTENT_DUE = "ThaskDueTasks"
INTENT_ADD = "ThaskAddTask"

PERIODS = ("today", "this_week", "this_month", "overdue")
LANGUAGES = ("de", "en")

# How many titles are read out; the rest is only counted.
READ_LIMIT = 5


def due_tasks(tasks: Iterable[Task], period: str, today: date, rolling: bool = False) -> list[Task]:
    """Open tasks for a voice question. Unlike the views, every period includes what is overdue."""
    match period:
        case "overdue":
            found = [task for task in tasks if task.overdue(today)]
        case "today":
            found = [task for task in tasks if not task.completed and task.due_by(today)]
        case "this_week":
            end = this_week_range(today, rolling)[1]
            found = [task for task in tasks if not task.completed and task.due_by(end)]
        case "this_month":
            end = Period(Granularity.MONTH, today).end
            found = [task for task in tasks if not task.completed and task.due_by(end)]
        case _:
            raise ValueError(period)
    return sorted(found, key=lambda task: (task.due.end, -task.priority, task.position))


def _lang(lang: str | None) -> str:
    code = (lang or "en").split("-")[0].lower()
    return code if code in LANGUAGES else "en"


_PERIOD_WORDS = {
    "de": {"today": "heute", "this_week": "diese Woche", "this_month": "diesen Monat"},
    "en": {"today": "today", "this_week": "this week", "this_month": "this month"},
}


def _join(lang: str, items: list[str]) -> str:
    word = "und" if lang == "de" else "and"
    return items[0] if len(items) == 1 else f"{', '.join(items[:-1])} {word} {items[-1]}"


def due_answer(lang: str | None, period: str, tasks: list[Task]) -> str:
    """What Assist says, e.g. "Heute sind 2 Aufgaben fällig: Steuer und Müll."."""
    lang = _lang(lang)
    titles = [task.title for task in tasks[:READ_LIMIT]]
    rest = len(tasks) - len(titles)
    if lang == "de":
        if rest:
            titles.append(f"{rest} weitere")
        if period == "overdue":
            if not tasks:
                return "Nichts ist überfällig."
            head = "Eine Aufgabe ist überfällig" if len(tasks) == 1 else f"{len(tasks)} Aufgaben sind überfällig"
        else:
            when = _PERIOD_WORDS[lang][period]
            when = when[0].upper() + when[1:]
            if not tasks:
                return f"{when} ist nichts fällig."
            head = f"{when} ist eine Aufgabe fällig" if len(tasks) == 1 else f"{when} sind {len(tasks)} Aufgaben fällig"
    else:
        if rest:
            titles.append(f"{rest} more")
        if period == "overdue":
            if not tasks:
                return "Nothing is overdue."
            head = "One task is overdue" if len(tasks) == 1 else f"{len(tasks)} tasks are overdue"
        else:
            when = _PERIOD_WORDS[lang][period]
            if not tasks:
                return f"Nothing is due {when}."
            head = f"One task is due {when}" if len(tasks) == 1 else f"{len(tasks)} tasks are due {when}"
    return f"{head}: {_join(lang, titles)}."


def added_answer(lang: str | None, title: str, list_name: str, due_label: str | None) -> str:
    """Confirmation after adding, e.g. "Steuer steht auf Aufgaben, fällig KW 47."."""
    if _lang(lang) == "de":
        return f"{title} steht auf {list_name}" + (f", fällig {due_label}." if due_label else ".")
    return f"Added {title} to {list_name}" + (f", due {due_label}." if due_label else ".")


_PREPOSITIONS = {"de": r"\s+(?:auf|in|zu|zur)\s+", "en": r"\s+(?:to|on|in)\s+"}
_FILLERS = {"de": r"^(?:die|der|meine|meiner|liste)\s+|\s+liste$", "en": r"^(?:my|the)\s+|\s+list$"}


def split_list(lang: str | None, text: str, lists: Iterable[TaskList]) -> tuple[str, TaskList | None]:
    """Split "Steuer auf die Liste Büro" into the text and a list, but only if that list exists."""
    lang = _lang(lang)
    by_name = {task_list.name.casefold(): task_list for task_list in lists}
    # The last preposition wins: "Brot zu Oma auf Einkauf" goes to "Einkauf".
    for match in reversed(list(re.finditer(_PREPOSITIONS[lang], text, re.IGNORECASE))):
        name = text[match.end() :].strip()
        while True:
            if (task_list := by_name.get(name.casefold())) is not None:
                return text[: match.start()].strip(), task_list
            shorter = re.sub(_FILLERS[lang], "", name, count=1, flags=re.IGNORECASE).strip()
            if shorter == name or not shorter:
                break
            name = shorter
    return text.strip(), None


_SENTENCES = {
    "de": """language: de
intents:
  ThaskDueTasks:
    data:
      - sentences:
          - "was (ist|steht) {thask_period:period} (fällig|an)"
          - "welche Aufgaben (sind|habe ich) {thask_period:period} [fällig]"
          - "was (muss|sollte) ich {thask_period:period} (erledigen|machen|tun)"
          - "was habe ich {thask_period:period} zu tun"
      - sentences:
          - "was ist überfällig"
          - "welche Aufgaben sind überfällig"
          - "was habe ich verpasst"
        slots:
          period: overdue
  ThaskAddTask:
    data:
      - sentences:
          - "(neue|notiere [die]) Aufgabe {thask_task:task}"
          - "notiere {thask_task:task}"
          - "ich muss (noch|unbedingt) {thask_task:task}"
lists:
  thask_period:
    values:
      - in: "heute"
        out: today
      - in: "(diese|in dieser|die) Woche"
        out: this_week
      - in: "(diesen|in diesem|den) Monat"
        out: this_month
  thask_task:
    wildcard: true
""",
    "en": """language: en
intents:
  ThaskDueTasks:
    data:
      - sentences:
          - "what('s| is) (due|on) {thask_period:period}"
          - "what do I (have|need) to do {thask_period:period}"
          - "which tasks are due {thask_period:period}"
      - sentences:
          - "what('s| is) overdue"
          - "which tasks are overdue"
        slots:
          period: overdue
  ThaskAddTask:
    data:
      - sentences:
          - "(new|add [a]) task {thask_task:task}"
          - "note [down] {thask_task:task}"
          - "I (have|need) to {thask_task:task}"
lists:
  thask_period:
    values:
      - in: "today"
        out: today
      - in: "this week"
        out: this_week
      - in: "this month"
        out: this_month
  thask_task:
    wildcard: true
""",
}


def sentences(lang: str) -> str:
    """The content of `custom_sentences/<lang>/thask.yaml`."""
    return "# Written by tHAsk (service thask.install_sentences); changes are overwritten.\n" + _SENTENCES[lang]
