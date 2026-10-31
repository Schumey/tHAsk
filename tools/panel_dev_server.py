"""Run the tHAsk panel in a browser without Home Assistant, backed by the real core logic.

    python tools/panel_dev_server.py [--port 8765]

Then open http://localhost:8765. Data lives in memory and starts with a few sample tasks.
The page fakes the parts of the `hass` object the panel uses (callWS, subscribeMessage).
"""

from __future__ import annotations

import argparse
from datetime import date, timedelta
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

LANGUAGE = "de"

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
  async function call(message) {
    const response = await fetch("/api", { method: "POST", body: JSON.stringify(message) });
    const body = await response.json();
    if (!response.ok) throw body;
    return body;
  }
  async function broadcast() {
    const snapshot = await call({ type: "thask/data" });
    listeners.forEach((listener) => listener({ type: "snapshot", ...snapshot }));
  }
  window.fakeHass = {
    language: "de",
    callWS: async (message) => {
      const result = await call(message);
      if (!["thask/data", "thask/parse", "thask/info"].includes(message.type)) broadcast();
      return result;
    },
    connection: {
      subscribeMessage: async (listener) => {
        listeners.add(listener);
        broadcast();
        return () => listeners.delete(listener);
      },
    },
  };
</script>
<script type="module" src="/thask_static/thask-panel.js"></script>
</head>
<body>
<thask-panel></thask-panel>
<script type="module">
  await customElements.whenDefined("thask-panel");
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
    collection.create_task(tasks.id, "Reifen wechseln", due=week.shift(1).as_dict(), important=True)
    collection.create_task(
        tasks.id,
        "Steuererklärung",
        due=Period(Granularity.QUARTER, today).shift(1).as_dict(),
        notes="Belege aus dem Ordner sammeln",
        steps=[{"title": "Belege scannen", "completed": True}, {"title": "Elster ausfüllen"}],
    )
    collection.create_task(tasks.id, "Zahnarzt anrufen", due=Period.day(today).as_dict(), due_time="09:30",
                           my_day=today.isoformat())
    collection.create_task(tasks.id, "Rechnungen ablegen", due=Period(Granularity.MONTH, today).as_dict(),
                           recurrence={"unit": "month", "interval": 1})
    collection.create_task(tasks.id, "Paket zurückschicken", due=Period.day(today - timedelta(days=2)).as_dict())
    done = collection.create_task(tasks.id, "Fenster putzen")
    collection.update_task(done.id, {"completed": True}, today)
    collection.create_task(shopping.id, "Milch", my_day=today.isoformat())
    collection.create_task(shopping.id, "Kaffee")
    collection.create_task(house.id, "Dachrinne prüfen", due=Period(Granularity.YEAR, today).as_dict())


class Backend:
    def __init__(self) -> None:
        self.today = date.today()
        self.collection = TaskCollection()
        seed(self.collection, self.today)

    def handle(self, msg: dict[str, Any]) -> Any:
        collection, today = self.collection, self.today
        pick = lambda fields: {key: value for key, value in msg.items() if key in fields}  # noqa: E731
        match msg["type"]:
            case "thask/data" | "thask/subscribe":
                return {
                    "today": today.isoformat(),
                    "lists": [item.as_dict() for item in collection.sorted_lists()],
                    "tasks": [task.as_dict() for task in collection.tasks.values()],
                }
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
        raise ValueError(f"Unknown command {msg['type']}")


BACKEND = Backend()


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path in ("/", "/index.html"):
            self._send(200, PAGE.encode(), "text/html; charset=utf-8")
        elif self.path.split("?")[0] == "/thask_static/thask-panel.js":
            self._send(200, (INTEGRATION / "www" / "thask-panel.js").read_bytes(), "text/javascript")
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
