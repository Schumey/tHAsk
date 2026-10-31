"""Export all Microsoft To Do lists and tasks into a JSON file that tHAsk can import.

Needs only Python 3.10+, no extra packages. Sign-in uses the device code flow: the script
shows a code, you sign in yourself in the browser, the script never sees your password.

    python ms_todo_export.py --client-id <application id> [--tenant consumers] [--output thask_ms_todo.json]

See README.md ("Import aus MS To-Do") for how to get a client id.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import sys
import time
from typing import Any
import urllib.error
import urllib.parse
import urllib.request

AUTHORITY = "https://login.microsoftonline.com/{tenant}/oauth2/v2.0"
GRAPH = "https://graph.microsoft.com/v1.0"
SCOPES = "Tasks.Read"


def _request(request: urllib.request.Request) -> tuple[int, dict[str, Any]]:
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as err:
        try:
            body = json.load(err)
        except ValueError:
            body = {}
        if err.code == 429:
            body["retry_after"] = int(err.headers.get("Retry-After", "10"))
        return err.code, body


def _post_form(url: str, data: dict[str, str]) -> tuple[int, dict[str, Any]]:
    return _request(urllib.request.Request(url, data=urllib.parse.urlencode(data).encode(), method="POST"))


def sign_in(client_id: str, tenant: str) -> str:
    base = AUTHORITY.format(tenant=tenant)
    status, code = _post_form(f"{base}/devicecode", {"client_id": client_id, "scope": SCOPES})
    if status != 200:
        sys.exit(f"Anmeldung konnte nicht gestartet werden: {code.get('error_description', code)}")
    print()
    print(f"Öffne {code['verification_uri']} und gib diesen Code ein: {code['user_code']}")
    print("Warte auf die Anmeldung …")

    interval = int(code.get("interval", 5))
    deadline = time.monotonic() + int(code.get("expires_in", 900))
    while time.monotonic() < deadline:
        time.sleep(interval)
        _, token = _post_form(
            f"{base}/token",
            {
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "client_id": client_id,
                "device_code": code["device_code"],
            },
        )
        if "access_token" in token:
            return token["access_token"]
        match token.get("error"):
            case "authorization_pending":
                continue
            case "slow_down":
                interval += 5
            case _:
                sys.exit(f"Anmeldung fehlgeschlagen: {token.get('error_description', token.get('error'))}")
    sys.exit("Anmeldung abgelaufen, bitte erneut starten.")


def get_all(url: str, token: str) -> list[dict[str, Any]]:
    """GET a Graph collection, following paging and honoring throttling."""
    items: list[dict[str, Any]] = []
    while url:
        request = urllib.request.Request(
            url,
            # Ask for all date-times in UTC so the importer can convert them reliably.
            headers={"Authorization": f"Bearer {token}", "Prefer": 'outlook.timezone="UTC"'},
        )
        status, body = _request(request)
        if status == 429:
            time.sleep(body["retry_after"])
            continue
        if status != 200:
            raise RuntimeError(f"{status} bei {url}: {body.get('error', body)}")
        items.extend(body.get("value", []))
        url = body.get("@odata.nextLink")
    return items


def export(token: str) -> dict[str, Any]:
    lists = get_all(f"{GRAPH}/me/todo/lists", token)
    for task_list in lists:
        list_url = f"{GRAPH}/me/todo/lists/{urllib.parse.quote(task_list['id'], safe='')}/tasks"
        try:
            tasks = get_all(f"{list_url}?$expand=checklistItems", token)
        except RuntimeError:
            # Fall back to fetching the steps task by task.
            tasks = get_all(list_url, token)
            for task in tasks:
                task_id = urllib.parse.quote(task["id"], safe="")
                task["checklistItems"] = get_all(f"{list_url}/{task_id}/checklistItems", token)
        task_list["tasks"] = tasks
        open_count = sum(task.get("status") != "completed" for task in tasks)
        print(f"  {task_list.get('displayName')}: {len(tasks)} Aufgaben ({open_count} offen)")
    return {
        "source": "ms_todo",
        "version": 1,
        "exported": datetime.now(timezone.utc).isoformat(),
        "lists": lists,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Microsoft To Do für tHAsk exportieren")
    parser.add_argument("--client-id", required=True, help="Anwendungs-ID (Client-ID) der App-Registrierung")
    parser.add_argument(
        "--tenant",
        default="consumers",
        help="consumers (privates Microsoft-Konto, Standard), organizations oder eine Tenant-ID",
    )
    parser.add_argument("--output", default="thask_ms_todo.json", help="Zieldatei")
    args = parser.parse_args()

    token = sign_in(args.client_id, args.tenant)
    print("Angemeldet. Lade Listen …")
    data = export(token)
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=1)
    total = sum(len(task_list["tasks"]) for task_list in data["lists"])
    print(f"Fertig: {len(data['lists'])} Listen, {total} Aufgaben → {args.output}")


if __name__ == "__main__":
    main()
