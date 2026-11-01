"""Run the tHAsk panel in a browser without Home Assistant, backed by the real core logic.

    python tools/panel_dev_server.py [--port 8765]

Then open http://localhost:8765. Data lives in memory and starts with a few sample tasks.
The page fakes the parts of the `hass` object the panel uses (callWS, subscribeMessage).
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import date, datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "custom_components" / "thask"
sys.path.insert(0, str(INTEGRATION))

from core.collection import NotFoundError, TaskCollection  # noqa: E402
from core.models import Task, TaskList  # noqa: E402
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
    user: { is_admin: true },
    states: Object.fromEntries([
      state("calendar.arbeit", "off", "Arbeit"),
      state("calendar.familie", "off", "Familie"),
      state("person.max", "home", "Max"),
      state("binary_sensor.waschmaschine", "off", "Waschmaschine"),
      state("sensor.aussentemperatur", "4.5", "Außentemperatur"),
    ].map((s) => [s.entity_id, s])),
    callWS: async (message) => {
      const result = await call(message);
      if (!["thask/data", "thask/parse", "thask/info", "thask/trigger/test"].includes(message.type)) broadcast();
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
    collection.create_task(tasks.id, "Reifen wechseln", due=week.shift(1).as_dict(), priority=3)
    collection.create_task(tasks.id, "Belege sortieren", due=week.as_dict())
    collection.create_task(
        tasks.id,
        "Steuererklärung",
        due=Period(Granularity.QUARTER, today).shift(1).as_dict(),
        notes="Belege aus dem Ordner sammeln",
        steps=[{"title": "Belege scannen", "completed": True}, {"title": "Elster ausfüllen"}],
    )
    collection.create_task(tasks.id, "Zahnarzt anrufen", due=Period.day(today).as_dict(), due_time="09:30")
    collection.create_task(tasks.id, "Rechnungen ablegen", due=Period(Granularity.MONTH, today).as_dict(),
                           recurrence={"unit": "month", "interval": 1})
    collection.create_task(tasks.id, "Paket zurückschicken", due=Period.day(today - timedelta(days=2)).as_dict())
    done = collection.create_task(tasks.id, "Fenster putzen")
    collection.update_task(done.id, {"completed": True}, today)
    collection.create_task(shopping.id, "Milch", due=Period.day(today).as_dict(), priority=3)
    collection.create_task(shopping.id, "Kaffee")
    collection.create_task(house.id, "Dachrinne prüfen", due=Period(Granularity.YEAR, today).as_dict())


class FakeSource:
    """States and calendar events for the trigger checks: an early shift tomorrow, Max at home."""

    def __init__(self, today: date) -> None:
        tomorrow = datetime.combine(today + timedelta(days=1), datetime.min.time()).astimezone()
        self.calendar = {
            "calendar.arbeit": [CalendarEvent("Frühschicht", tomorrow.replace(hour=6), tomorrow.replace(hour=14))],
            "calendar.familie": [CalendarEvent("Geburtstag Oma", today + timedelta(days=3), today + timedelta(days=4))],
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
        self.source = FakeSource(self.today)
        self.last_check: str | None = None
        seed_triggers(self.triggers, self.collection)
        # Options of the integration; "dev/options" changes them, e.g. {"overdue_in_today": "separate"}.
        self.options: dict[str, Any] = {
            "overdue_in_today": "section", "separate_week": False, "separate_month": False, "week_mode": "calendar", "hidden_views": [],
            "reminder_targets": [],
        }

    def handle(self, msg: dict[str, Any]) -> Any:
        collection, today = self.collection, self.today
        pick = lambda fields: {key: value for key, value in msg.items() if key in fields}  # noqa: E731
        match msg["type"]:
            case "thask/data" | "thask/subscribe":
                return {
                    "today": today.isoformat(),
                    "options": self.options,
                    "lists": [item.as_dict() for item in collection.sorted_lists()],
                    "tasks": [task.as_dict() for task in collection.tasks.values()],
                }
            case "dev/options" | "thask/options/update":
                self.options.update({key: value for key, value in msg.items() if key not in ("type", "id")})
                return {"options": self.options}
            case "thask/options/get":
                return {"options": self.options, "notify_services": ["mobile_app_pixel_7", "persistent_notification"]}
            case "thask/parse":
                return parse(msg["text"], today, set(msg.get("disabled", []))).as_dict(LANGUAGE, today)
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
    card.setConfig(JSON.parse(card.dataset.config));
    card.hass = window.fakeHass;
  }""",
)


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
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
        msg = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        try:
            result = BACKEND.handle(msg)
            self._send(200, json.dumps(result).encode(), "application/json")
        except (NotFoundError, ValueError, KeyError) as err:
            self._send(400, json.dumps({"message": str(err)}).encode(), "application/json")

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
