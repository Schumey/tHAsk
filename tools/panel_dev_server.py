"""Run the tHAsk panel in a browser without Home Assistant, backed by the real core logic.

    python tools/panel_dev_server.py [--port 8765]

Then open http://localhost:8765. Data lives in memory and starts with a few sample tasks.
The page fakes the parts of the `hass` object the panel uses (callWS, subscribeMessage).
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import date, datetime, timedelta
from email import policy as email_policy
from email.parser import BytesParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "custom_components" / "thask"
sys.path.insert(0, str(INTEGRATION))

from core.collection import NotFoundError, TaskCollection  # noqa: E402
from core.custom_periods import PeriodBook, PeriodRule  # noqa: E402
from core.models import Attachment, Task, TaskList, new_id  # noqa: E402
from core.parser import parse  # noqa: E402
from core.period import Granularity, Period  # noqa: E402
from core.triggers import CalendarEvent, EntityState, Evaluator, Trigger, TriggerBook  # noqa: E402

LANGUAGE = "de"
VERSION = json.loads((INTEGRATION / "manifest.json").read_text(encoding="utf-8"))["version"]

PAGE = """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>tHAsk dev</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@mdi/font@7.4.47/css/materialdesignicons.min.css">
<style>
  html, body { margin: 0; height: 100%; }
  body { --primary-color: #03a9f4; }
  @media (prefers-color-scheme: dark) {
    body { --primary-background-color: #111; --card-background-color: #1c1c1c; --secondary-background-color: #202020;
      --primary-text-color: #e1e1e1; --secondary-text-color: #9b9b9b; --divider-color: rgba(225,225,225,.12); background: #111; }
  }
</style>
<script>
  // Minimal stand-ins for Home Assistant elements used by the panel.
  customElements.define("ha-icon", class extends HTMLElement {
    static observedAttributes = ["icon"];
    connectedCallback() { this.render(); }
    attributeChangedCallback() { this.render(); }
    render() {
      if (!this.shadowRoot) this.attachShadow({ mode: "open" });
      const name = (this.getAttribute("icon") || "").replace("mdi:", "");
      this.shadowRoot.innerHTML = `<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@mdi/font@7.4.47/css/materialdesignicons.min.css">
        <style>:host{display:inline-flex;width:var(--mdc-icon-size,24px);height:var(--mdc-icon-size,24px);align-items:center;justify-content:center}
        i{font-size:var(--mdc-icon-size,24px);line-height:1}</style><i class="mdi mdi-${name}"></i>`;
    }
  });
  customElements.define("ha-menu-button", class extends HTMLElement {});

  const listeners = new Set();
  const triggerListeners = new Set();
  async function call(message) {
    const response = await fetch("/api", { method: "POST", body: JSON.stringify(message) });
    const body = await response.json();
    if (!response.ok) throw body;
    return body;
  }
  async function broadcast() {
    const snapshot = await call({ type: "thask/data" });
    listeners.forEach((listener) => listener({ type: "snapshot", ...snapshot }));
    if (triggerListeners.size) {
      const triggers = await call({ type: "thask/triggers/data" });
      triggerListeners.forEach((listener) => listener(triggers));
    }
  }
  // A few entities for the trigger form.
  const state = (entity_id, value, friendly_name) => ({ entity_id, state: value, attributes: { friendly_name } });
  window.fakeHass = {
    // ?lang=fr shows another language.
    language: new URLSearchParams(location.search).get("lang") || "de",
    user: { id: "u-max", is_admin: true },
    states: Object.fromEntries([
      state("calendar.arbeit", "off", "Arbeit"),
      state("calendar.familie", "off", "Familie"),
      state("calendar.schichtplan", "off", "Schichtplan"),
      state("person.max", "home", "Max"),
      state("binary_sensor.waschmaschine", "off", "Waschmaschine"),
      state("sensor.aussentemperatur", "4.5", "Außentemperatur"),
    ].map((s) => [s.entity_id, s])),
    // Attachments go over HTTP like in Home Assistant; links need no signature here.
    fetchWithAuth: async (path, init) => {
      const response = await fetch(path, init);
      broadcast();
      return response;
    },
    callWS: async (message) => {
      if (message.type === "auth/sign_path") return { path: message.path };
      const result = await call(message);
      if (!["thask/data", "thask/parse", "thask/info", "thask/trigger/test", "thask/period_rules/get"].includes(message.type)) broadcast();
      return result;
    },
    connection: {
      subscribeMessage: async (listener, message) => {
        const set = message.type === "thask/triggers/subscribe" ? triggerListeners : listeners;
        set.add(listener);
        broadcast();
        return () => set.delete(listener);
      },
    },
  };
</script>
<script type="module" src="/thask_static/thask-panel.js?v=__VERSION__"></script>
<script type="module" src="/thask_static/thask-card.js?v=__VERSION__"></script>
</head>
<body>
<thask-panel></thask-panel>
<script>
  // Like Home Assistant: hass and narrow are set right away, possibly before the module has defined the element.
  const panel = document.querySelector("thask-panel");
  const narrow = () => (panel.narrow = window.innerWidth < 870);
  narrow();
  window.addEventListener("resize", narrow);
  panel.hass = window.fakeHass;
</script>
</body>
</html>
"""


def seed(collection: TaskCollection, today: date) -> None:
    tasks = collection.create_list("Aufgaben")
    shopping = collection.create_list("Einkauf")
    house = collection.create_list("Haus", group="Zuhause")
    week = Period(Granularity.WEEK, today)
    collection.create_task(tasks.id, "Reifen wechseln", due=week.shift(1).as_dict(), priority=3, categories=["Auto"])
    collection.create_task(tasks.id, "Belege sortieren", due=week.as_dict())
    collection.create_task(
        tasks.id,
        "Steuererklärung",
        due=Period(Granularity.QUARTER, today).shift(1).as_dict(),
        notes="Belege aus dem Ordner sammeln",
        steps=[{"title": "Belege scannen", "completed": True}, {"title": "Elster ausfüllen"}],
    )
    collection.create_task(tasks.id, "Zahnarzt anrufen", due=Period.day(today).as_dict(), due_time="09:30", categories=["Anrufe"])
    collection.create_task(tasks.id, "Rechnungen ablegen", due=Period(Granularity.MONTH, today).as_dict(),
                           recurrence={"unit": "month", "interval": 1})
    collection.create_task(tasks.id, "Paket zurückschicken", due=Period.day(today - timedelta(days=2)).as_dict())
    done = collection.create_task(tasks.id, "Fenster putzen")
    collection.update_task(done.id, {"completed": True}, today)
    collection.create_task(shopping.id, "Milch", due=Period.day(today).as_dict(), priority=3)
    collection.create_task(shopping.id, "Kaffee")
    collection.create_task(house.id, "Dachrinne prüfen", due=Period(Granularity.YEAR, today).as_dict())
    # Recurring tasks for the day plan's previews.
    collection.create_task(house.id, "Mülltonne rausstellen", due=Period.day(today).as_dict(), due_time="19:00",
                           recurrence={"unit": "week", "interval": 1, "weekdays": [1, 4]})
    collection.create_task(house.id, "Blumen gießen", due=Period.day(today - timedelta(days=1)).as_dict(),
                           recurrence={"unit": "day", "interval": 3})


class FakeSource:
    """States and calendar events for the trigger checks: an early shift tomorrow, Max at home."""

    def __init__(self, today: date) -> None:
        tomorrow = datetime.combine(today + timedelta(days=1), datetime.min.time()).astimezone()
        self.calendar = {
            "calendar.arbeit": [CalendarEvent("Frühschicht", tomorrow.replace(hour=6), tomorrow.replace(hour=14))],
            "calendar.familie": [CalendarEvent("Geburtstag Oma", today + timedelta(days=3), today + timedelta(days=4))],
            "calendar.schichtplan": shift_plan(today),
        }
        self.states = {
            "person.max": EntityState("home", datetime.now().astimezone() - timedelta(hours=2)),
            "binary_sensor.waschmaschine": EntityState("off", datetime.now().astimezone()),
            "sensor.aussentemperatur": EntityState("4.5", datetime.now().astimezone()),
        }

    def state(self, entity_id):
        return self.states.get(entity_id)

    async def events(self, entity_id, start, end):
        if entity_id not in self.calendar:
            raise ValueError(f"{entity_id} not found")
        return self.calendar[entity_id]


def shift_plan(today: date) -> list[CalendarEvent]:
    """A three week rotation: nights Mon and Tue (ending Wednesday), then a free stretch; early shifts;
    late shifts. Every other rotation has a training day in the free stretch, so not every one is an X block."""
    monday = today - timedelta(days=today.weekday()) - timedelta(weeks=3)
    tz = datetime.now().astimezone().tzinfo
    events: list[CalendarEvent] = []
    for rotation in range(10):
        week = monday + timedelta(weeks=3 * rotation)
        for offset in (0, 1):
            start = datetime.combine(week + timedelta(days=offset), datetime.min.time(), tz).replace(hour=20)
            events.append(CalendarEvent("Nachtschicht", start, start + timedelta(hours=10)))
        free = [week + timedelta(days=8)] + ([week + timedelta(days=9), week + timedelta(days=10), week + timedelta(days=11)] if rotation % 2 else [])
        events += [CalendarEvent("Schulung", day, day + timedelta(days=1)) for day in free]
        for offset in range(14, 19):
            events.append(CalendarEvent("Frühschicht", week + timedelta(days=offset), week + timedelta(days=offset + 1)))
    return events


def seed_triggers(book: TriggerBook, collection: TaskCollection) -> None:
    book.create(
        {
            "name": "Frühschicht",
            "conditions": [{"kind": "calendar", "entity": "calendar.arbeit", "match": "Frühschicht", "part": "start"}],
            "days_ahead": 1,
            "task": {"title": "{termin} vorbereiten", "list_id": collection.default_list().id, "due": "day_before"},
        }
    )


class Backend:
    def __init__(self) -> None:
        self.today = date.today()
        self.collection = TaskCollection()
        seed(self.collection, self.today)
        self.triggers = TriggerBook()
        # Uploaded attachments, in memory: attachment id -> content.
        self.files: dict[str, bytes] = {}
        self.source = FakeSource(self.today)
        self.last_check: str | None = None
        seed_triggers(self.triggers, self.collection)
        self.periods = PeriodBook()
        self.collection.custom_resolver = lambda rule, after, today: self.periods.next_after(rule, after, today)
        self.periods.create({"name": "X-Block", "calendar": "calendar.schichtplan", "anchor_match": "Nacht", "anchor_weekdays": [2]})
        self.refresh_periods()
        # Options of the integration; "dev/options" changes them, e.g. {"overdue_in_today": "separate"}.
        self.options: dict[str, Any] = {
            "overdue_in_today": "section", "separate_week": False, "separate_month": False, "week_mode": "calendar", "hidden_views": [], "auto_clear_days": 0, "important_priority": "high",
            "reminder_targets": [],
        }

    def refresh_periods(self, rule_ids: list[str] | None = None) -> None:
        asyncio.run(self.periods.refresh(self.source, self.today, datetime.now().astimezone().tzinfo, rule_ids))

    def period_rules(self) -> dict[str, Any]:
        return {
            "rules": [
                {
                    **rule.as_dict(),
                    "instances": [p.as_dict() for p in self.periods.upcoming(rule.id, self.today)],
                    "error": self.periods.errors.get(rule.id),
                }
                for rule in self.periods.sorted_rules()
            ]
        }

    def custom(self) -> list[tuple[str, list[Period]]]:
        return [(rule.name, self.periods.upcoming(rule.id, self.today)) for rule in self.periods.sorted_rules() if rule.enabled]

    def handle(self, msg: dict[str, Any]) -> Any:
        collection, today = self.collection, self.today
        pick = lambda fields: {key: value for key, value in msg.items() if key in fields}  # noqa: E731
        match msg["type"]:
            case "thask/data" | "thask/subscribe":
                return {
                    "today": today.isoformat(),
                    "me": "u-max",
                    "options": self.options,
                    "lists": [item.as_dict() for item in collection.sorted_lists()],
                    "tasks": [task.as_dict() for task in collection.tasks.values()],
                    "periods": self.periods.public(today),
                }
            case "dev/options" | "thask/options/update":
                self.options.update({key: value for key, value in msg.items() if key not in ("type", "id")})
                return {"options": self.options}
            case "thask/users":
                return {"me": "u-max", "users": [{"id": "u-anna", "name": "Anna"}, {"id": "u-max", "name": "Max"}]}
            case "thask/options/get":
                return {"options": self.options, "notify_services": ["mobile_app_pixel_7", "persistent_notification"]}
            case "thask/parse":
                return parse(msg["text"], today, set(msg.get("disabled", [])), self.custom()).as_dict(LANGUAGE, today)
            case "thask/period_rules/get":
                return self.period_rules()
            case "thask/period_rule/create":
                rule = self.periods.create(pick(PeriodRule.EDITABLE))
                self.refresh_periods([rule.id])
                return {**self.period_rules(), "rule_id": rule.id}
            case "thask/period_rule/update":
                self.periods.update(msg["rule_id"], pick(PeriodRule.EDITABLE))
                self.refresh_periods([msg["rule_id"]])
                return self.period_rules()
            case "thask/period_rule/delete":
                self.periods.delete(msg["rule_id"])
                return self.period_rules()
            case "thask/period_rules/refresh":
                self.refresh_periods()
                return self.period_rules()
            case "thask/list/create":
                fields = pick(TaskList.EDITABLE)
                return collection.create_list(fields.pop("name"), **fields).as_dict()
            case "thask/list/update":
                return collection.update_list(msg["list_id"], pick(TaskList.EDITABLE)).as_dict()
            case "thask/list/delete":
                collection.delete_list(msg["list_id"])
                return None
            case "thask/list/move":
                return collection.move_list(msg["list_id"], msg.get("previous_id")).as_dict()
            case "thask/list/clear_completed":
                return {"removed": collection.clear_completed(msg.get("list_id"))}
            case "thask/task/create":
                fields = pick(Task.EDITABLE)
                return collection.create_task(fields.pop("list_id"), fields.pop("title"), **fields).as_dict()
            case "thask/task/update":
                return collection.update_task(msg["task_id"], pick(Task.EDITABLE), today).as_dict()
            case "thask/task/delete":
                collection.delete_task(msg["task_id"])
                return None
            case "thask/task/occurrence":
                occurrence = collection.set_occurrence(msg["task_id"], Period.from_dict(msg["due"]), msg["done"], today)
                return occurrence.as_dict() if occurrence else None
            case "thask/attachment/delete":
                collection.remove_attachment(msg["task_id"], msg["attachment_id"])
                self.files.pop(msg["attachment_id"], None)
                return None
            case "thask/task/move":
                return collection.move_task(msg["task_id"], msg.get("previous_id")).as_dict()
            case "thask/triggers/data":
                return {
                    "triggers": [trigger.as_dict() for trigger in self.triggers.sorted_triggers()],
                    "runs": [run.as_dict() for run in self.triggers.recent_runs()],
                    "status": {"last_check": self.last_check, "errors": self.triggers.errors},
                }
            case "thask/trigger/create":
                return self.triggers.create(pick(Trigger.EDITABLE)).as_dict()
            case "thask/trigger/update":
                return self.triggers.update(msg["trigger_id"], pick(Trigger.EDITABLE)).as_dict()
            case "thask/trigger/delete":
                self.triggers.delete(msg["trigger_id"])
                return None
            case "thask/trigger/test":
                trigger = self.triggers.get(msg["trigger_id"])
                days = trigger.target_days(today)
                evaluator = Evaluator(self.source, datetime.now().astimezone())
                matches = [asyncio.run(evaluator.evaluate(trigger, day, days[-1])) for day in days]
                match = next((m for m in matches if m.met), matches[0])
                return {"met": match.met, "results": match.results, "event": match.event.summary if match.event else None}
            case "thask/trigger/run":
                trigger = self.triggers.get(msg["trigger_id"])
                return self.triggers.fire(trigger, collection, today, today, LANGUAGE, manual=True).as_dict()
            case "thask/trigger/check":
                now = datetime.now().astimezone()
                fired = asyncio.run(self.triggers.check(collection, self.source, now, LANGUAGE))
                self.last_check = now.isoformat()
                return {"fired": [run.as_dict() for run in fired]}
            case "thask/trigger/undo":
                return self.triggers.undo(msg["run_id"], collection).as_dict()
        raise ValueError(f"Unknown command {msg['type']}")


BACKEND = Backend()

# The dashboard card in a few configurations, with the same fake hass as the panel page.
CARD_PAGE = PAGE.replace("<thask-panel></thask-panel>", """<div class="cards">
  <thask-card data-config='{"view": "my_day"}'></thask-card>
  <thask-card data-config='{"view": "planned", "show_completed": true, "max_items": 4}'></thask-card>
  <thask-card data-config='{"view": "this_week", "compact": true, "show_entry": false, "title": "Woche kompakt"}'></thask-card>
  <thask-card data-config='{"views": ["my_day", "this_week"]}'></thask-card>
  <thask-card data-config='{"views": ["my_day", "this_week", "important"], "tabs": true}'></thask-card>
  <thask-card data-config='{"view": "list:first", "show_completed": true}'></thask-card>
  <thask-card data-config='{"view": "this_week", "categories": ["Anrufe"], "title": "Anrufe"}'></thask-card>
  <thask-card data-config='{"view": "overdue", "hide_if_empty": true, "title": "Überfällig (verschwindet, wenn leer)"}'></thask-card>
  <thask-card data-config='{"views": ["day_view", "this_week"]}'></thask-card>
</div>
<style>.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 12px; padding: 12px; }
  ha-card { display: block; background: var(--card-background-color, #fff); border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,.2); }</style>""").replace(
    """<script>
  // Like Home Assistant: hass and narrow are set right away, possibly before the module has defined the element.
  const panel = document.querySelector("thask-panel");
  const narrow = () => (panel.narrow = window.innerWidth < 870);
  narrow();
  window.addEventListener("resize", narrow);
  panel.hass = window.fakeHass;""",
    """<script type="module">
  await customElements.whenDefined("thask-card");
  if (!customElements.get("ha-card")) customElements.define("ha-card", class extends HTMLElement {});
  for (const card of document.querySelectorAll("thask-card")) {
    // "list:first" stands for the first list of the sample data, whose id changes with every start.
    const config = JSON.parse(card.dataset.config);
    if (config.view === "list:first") config.view = `list:${(await window.fakeHass.callWS({ type: "thask/data" })).lists[0].id}`;
    card.setConfig(config);
    card.hass = window.fakeHass;
  }""",
)


ATTACHMENT_URL = "/api/thask/attachments/"


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = self.path.split("?")[0]
        if path.startswith(ATTACHMENT_URL):
            task_id, _, attachment_id = path.removeprefix(ATTACHMENT_URL).partition("/")
            try:
                attachment = BACKEND.collection.get_attachment(task_id, attachment_id)
            except NotFoundError:
                self._send(404, b"not found", "text/plain")
                return
            self._send(200, BACKEND.files.get(attachment_id, b""), attachment.content_type)
        elif path in ("/", "/index.html"):
            self._send(200, PAGE.replace("__VERSION__", VERSION).encode(), "text/html; charset=utf-8")
        elif path in ("/card", "/card.html"):
            self._send(200, CARD_PAGE.replace("__VERSION__", VERSION).encode(), "text/html; charset=utf-8")
        elif self.path.startswith("/thask_static/") and (
            file := INTEGRATION / "www" / self.path.split("?")[0].removeprefix("/thask_static/")
        ).is_file():
            self._send(200, file.read_bytes(), "text/javascript")
        else:
            self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:
        if self.path.startswith(ATTACHMENT_URL):
            self._upload(self.path.removeprefix(ATTACHMENT_URL))
            return
        msg = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        try:
            result = BACKEND.handle(msg)
            self._send(200, json.dumps(result).encode(), "application/json")
        except (NotFoundError, ValueError, KeyError) as err:
            self._send(400, json.dumps({"message": str(err)}).encode(), "application/json")

    def _upload(self, task_id: str) -> None:
        body = self.rfile.read(int(self.headers["Content-Length"]))
        head = f"Content-Type: {self.headers['Content-Type']}\r\n\r\n".encode()
        message = BytesParser(policy=email_policy.default).parsebytes(head + body)
        part = next((part for part in message.iter_parts() if part.get_param("name", header="content-disposition") == "file"), None)
        if part is None or task_id not in BACKEND.collection.tasks:
            self._send(400, json.dumps({"message": "no file or task"}).encode(), "application/json")
            return
        content = part.get_payload(decode=True) or b""
        attachment = Attachment(new_id(), part.get_filename() or "file", len(content), part.get_content_type())
        BACKEND.files[attachment.id] = content
        BACKEND.collection.add_attachment(task_id, attachment)
        self._send(200, json.dumps(attachment.as_dict()).encode(), "application/json")

    def log_message(self, *args: Any) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    print(f"tHAsk panel: http://localhost:{args.port}")
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
