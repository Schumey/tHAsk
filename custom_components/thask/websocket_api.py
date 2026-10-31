"""WebSocket API used by the tHAsk apps. All commands are prefixed with "thask/"."""

from __future__ import annotations

from collections.abc import Callable
from datetime import timedelta
from functools import wraps
from typing import Any

import voluptuous as vol

from homeassistant.components import websocket_api
from homeassistant.core import HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.util import dt as dt_util

from .const import SIGNAL_DAY_CHANGED, SIGNAL_TRIGGERS_CHANGED
from .core.collection import Change, NotFoundError
from .core.models import Task, TaskList
from .core.parser import KIND_DUE, KIND_PRIORITY, KIND_RECURRENCE, KIND_TIME, parse
from .core.triggers import Trigger
from .data import ThaskData, async_get_data
from .schema import (
    LIST_FIELDS,
    TASK_FIELDS,
    TASK_TEMPLATE_SCHEMA,
    TRIGGER_CONDITIONS,
    TRIGGER_FIELDS,
    TRIGGER_NAME,
)

# Bumped when the API changes incompatibly, so apps can tell the user to update.
API_VERSION = 1

type Handler = Callable[[HomeAssistant, websocket_api.ActiveConnection, dict[str, Any], ThaskData], None]


@callback
def async_register_websocket_commands(hass: HomeAssistant) -> None:
    for command in (
        ws_info,
        ws_data,
        ws_subscribe,
        ws_list_create,
        ws_list_update,
        ws_list_delete,
        ws_list_move,
        ws_list_clear_completed,
        ws_task_create,
        ws_task_update,
        ws_task_delete,
        ws_task_move,
        ws_parse,
        ws_triggers_subscribe,
        ws_trigger_create,
        ws_trigger_update,
        ws_trigger_delete,
        ws_trigger_test,
        ws_trigger_run,
        ws_trigger_check,
        ws_trigger_undo,
    ):
        websocket_api.async_register_command(hass, command)


def _with_data(handler: Handler) -> Callable[[HomeAssistant, websocket_api.ActiveConnection, dict[str, Any]], None]:
    """Resolve the loaded entry and turn missing ids into proper errors."""

    @wraps(handler)
    def wrapper(hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]) -> None:
        try:
            handler(hass, connection, msg, async_get_data(hass))
        except NotFoundError as err:
            connection.send_error(msg["id"], websocket_api.ERR_NOT_FOUND, f"Not found: {err.args[0]}")
        except HomeAssistantError as err:
            connection.send_error(msg["id"], websocket_api.ERR_HOME_ASSISTANT_ERROR, str(err))

    return callback(wrapper)


def _patch(msg: dict[str, Any], fields: tuple[str, ...]) -> dict[str, Any]:
    return {key: value for key, value in msg.items() if key in fields}


def _snapshot(data: ThaskData) -> dict[str, Any]:
    return {
        "today": data.today.isoformat(),
        "lists": [task_list.as_dict() for task_list in data.collection.sorted_lists()],
        "tasks": [task.as_dict() for task in data.collection.tasks.values()],
    }


@websocket_api.websocket_command({vol.Required("type"): "thask/info"})
@_with_data
def ws_info(hass, connection, msg, data: ThaskData) -> None:
    connection.send_result(
        msg["id"],
        {"api_version": API_VERSION, "today": data.today.isoformat(), "language": data.language},
    )


@websocket_api.websocket_command({vol.Required("type"): "thask/data"})
@_with_data
def ws_data(hass, connection, msg, data: ThaskData) -> None:
    connection.send_result(msg["id"], _snapshot(data))


@websocket_api.websocket_command({vol.Required("type"): "thask/subscribe"})
@_with_data
def ws_subscribe(hass, connection, msg, data: ThaskData) -> None:
    """Send a snapshot, then every change and a notice when the day changes."""

    @callback
    def forward_change(change: Change) -> None:
        connection.send_message(websocket_api.event_message(msg["id"], {"type": "change", **change.as_dict()}))

    @callback
    def forward_day_changed() -> None:
        connection.send_message(
            websocket_api.event_message(msg["id"], {"type": "day_changed", "today": data.today.isoformat()})
        )

    unsubs = [
        data.collection.subscribe(forward_change),
        async_dispatcher_connect(hass, SIGNAL_DAY_CHANGED, forward_day_changed),
    ]

    @callback
    def unsubscribe() -> None:
        for unsub in unsubs:
            unsub()

    connection.subscriptions[msg["id"]] = unsubscribe
    connection.send_result(msg["id"])
    connection.send_message(websocket_api.event_message(msg["id"], {"type": "snapshot", **_snapshot(data)}))


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/list/create", vol.Required("name"): str, **LIST_FIELDS}
)
@_with_data
def ws_list_create(hass, connection, msg, data: ThaskData) -> None:
    fields = _patch(msg, TaskList.EDITABLE)
    task_list = data.collection.create_list(fields.pop("name"), **fields)
    connection.send_result(msg["id"], task_list.as_dict())


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/list/update", vol.Required("list_id"): str, **LIST_FIELDS}
)
@_with_data
def ws_list_update(hass, connection, msg, data: ThaskData) -> None:
    task_list = data.collection.update_list(msg["list_id"], _patch(msg, TaskList.EDITABLE))
    connection.send_result(msg["id"], task_list.as_dict())


@websocket_api.websocket_command({vol.Required("type"): "thask/list/delete", vol.Required("list_id"): str})
@_with_data
def ws_list_delete(hass, connection, msg, data: ThaskData) -> None:
    if len(data.collection.lists) == 1 and msg["list_id"] in data.collection.lists:
        raise HomeAssistantError("The last list cannot be deleted")
    data.collection.delete_list(msg["list_id"])
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/list/move",
        vol.Required("list_id"): str,
        vol.Optional("previous_id"): vol.Any(None, str),
    }
)
@_with_data
def ws_list_move(hass, connection, msg, data: ThaskData) -> None:
    task_list = data.collection.move_list(msg["list_id"], msg.get("previous_id"))
    connection.send_result(msg["id"], task_list.as_dict())


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/list/clear_completed",
        vol.Optional("list_id"): vol.Any(None, str),
        vol.Optional("older_than_days"): vol.All(vol.Coerce(int), vol.Range(min=0)),
    }
)
@_with_data
def ws_list_clear_completed(hass, connection, msg, data: ThaskData) -> None:
    """Delete completed tasks of one list (or all lists)."""
    before = None
    if "older_than_days" in msg:
        before = dt_util.utcnow() - timedelta(days=msg["older_than_days"])
    removed = data.collection.clear_completed(msg.get("list_id"), before)
    connection.send_result(msg["id"], {"removed": removed})


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/task/create",
        **{key: value for key, value in TASK_FIELDS.items() if key not in ("list_id", "title")},
        vol.Required("list_id"): str,
        vol.Required("title"): vol.All(str, vol.Length(min=1)),
    }
)
@_with_data
def ws_task_create(hass, connection, msg, data: ThaskData) -> None:
    fields = _patch(msg, Task.EDITABLE)
    task = data.collection.create_task(fields.pop("list_id"), fields.pop("title"), **fields)
    connection.send_result(msg["id"], task.as_dict())


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/task/update", vol.Required("task_id"): str, **TASK_FIELDS}
)
@_with_data
def ws_task_update(hass, connection, msg, data: ThaskData) -> None:
    task = data.collection.update_task(msg["task_id"], _patch(msg, Task.EDITABLE), data.today)
    connection.send_result(msg["id"], task.as_dict())


@websocket_api.websocket_command({vol.Required("type"): "thask/task/delete", vol.Required("task_id"): str})
@_with_data
def ws_task_delete(hass, connection, msg, data: ThaskData) -> None:
    data.collection.delete_task(msg["task_id"])
    connection.send_result(msg["id"])


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/task/move",
        vol.Required("task_id"): str,
        vol.Optional("previous_id"): vol.Any(None, str),
    }
)
@_with_data
def ws_task_move(hass, connection, msg, data: ThaskData) -> None:
    task = data.collection.move_task(msg["task_id"], msg.get("previous_id"))
    connection.send_result(msg["id"], task.as_dict())


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/parse",
        vol.Required("text"): str,
        vol.Optional("disabled", default=[]): [vol.In([KIND_DUE, KIND_TIME, KIND_RECURRENCE, KIND_PRIORITY])],
    }
)
@_with_data
def ws_parse(hass, connection, msg, data: ThaskData) -> None:
    """Quick entry preview: split typed text into title and structured fields."""
    result = parse(msg["text"], data.today, set(msg["disabled"]))
    connection.send_result(msg["id"], result.as_dict(data.language, data.today))


# -- triggers -------------------------------------------------------------------------------------


def _triggers_snapshot(data: ThaskData) -> dict[str, Any]:
    return {
        "triggers": [trigger.as_dict() for trigger in data.triggers.sorted_triggers()],
        "runs": [run.as_dict() for run in data.triggers.recent_runs()],
        "status": data.trigger_status(),
    }


def _async_with_data(handler):
    """Like _with_data, for handlers that await (calendar requests)."""

    @wraps(handler)
    async def wrapper(hass: HomeAssistant, connection: websocket_api.ActiveConnection, msg: dict[str, Any]) -> None:
        try:
            await handler(hass, connection, msg, async_get_data(hass))
        except NotFoundError as err:
            connection.send_error(msg["id"], websocket_api.ERR_NOT_FOUND, f"Not found: {err.args[0]}")
        except (HomeAssistantError, ValueError) as err:
            connection.send_error(msg["id"], websocket_api.ERR_HOME_ASSISTANT_ERROR, str(err))

    return websocket_api.async_response(wrapper)


@websocket_api.websocket_command({vol.Required("type"): "thask/triggers/subscribe"})
@websocket_api.require_admin
@_with_data
def ws_triggers_subscribe(hass, connection, msg, data: ThaskData) -> None:
    """Triggers, recent runs and check status; sent again after every change and check."""

    @callback
    def forward() -> None:
        connection.send_message(websocket_api.event_message(msg["id"], _triggers_snapshot(data)))

    connection.subscriptions[msg["id"]] = async_dispatcher_connect(hass, SIGNAL_TRIGGERS_CHANGED, forward)
    connection.send_result(msg["id"])
    forward()


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/trigger/create",
        **{key: value for key, value in TRIGGER_FIELDS.items() if key not in ("name", "conditions", "task")},
        vol.Required("name"): TRIGGER_NAME,
        vol.Required("conditions"): TRIGGER_CONDITIONS,
        vol.Required("task"): TASK_TEMPLATE_SCHEMA,
    }
)
@websocket_api.require_admin
@_with_data
def ws_trigger_create(hass, connection, msg, data: ThaskData) -> None:
    trigger = data.triggers.create(_patch(msg, Trigger.EDITABLE))
    connection.send_result(msg["id"], trigger.as_dict())


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/trigger/update", vol.Required("trigger_id"): str, **TRIGGER_FIELDS}
)
@websocket_api.require_admin
@_with_data
def ws_trigger_update(hass, connection, msg, data: ThaskData) -> None:
    trigger = data.triggers.update(msg["trigger_id"], _patch(msg, Trigger.EDITABLE))
    connection.send_result(msg["id"], trigger.as_dict())


@websocket_api.websocket_command({vol.Required("type"): "thask/trigger/delete", vol.Required("trigger_id"): str})
@websocket_api.require_admin
@_with_data
def ws_trigger_delete(hass, connection, msg, data: ThaskData) -> None:
    data.triggers.delete(msg["trigger_id"])
    connection.send_result(msg["id"])


@websocket_api.websocket_command({vol.Required("type"): "thask/trigger/test", vol.Required("trigger_id"): str})
@websocket_api.require_admin
@_async_with_data
async def ws_trigger_test(hass, connection, msg, data: ThaskData) -> None:
    """Whether the conditions apply right now (per condition), without creating a task."""
    match = await data.async_test_trigger(msg["trigger_id"])
    connection.send_result(
        msg["id"],
        {"met": match.met, "results": match.results, "event": match.event.summary if match.event else None},
    )


@websocket_api.websocket_command({vol.Required("type"): "thask/trigger/run", vol.Required("trigger_id"): str})
@websocket_api.require_admin
@_with_data
def ws_trigger_run(hass, connection, msg, data: ThaskData) -> None:
    """Create the trigger's task for today now, regardless of its conditions."""
    connection.send_result(msg["id"], data.run_trigger_now(msg["trigger_id"]).as_dict())


@websocket_api.websocket_command({vol.Required("type"): "thask/trigger/check"})
@websocket_api.require_admin
@_async_with_data
async def ws_trigger_check(hass, connection, msg, data: ThaskData) -> None:
    """Check all triggers now instead of waiting for the next minute."""
    fired = await data.async_check_triggers()
    connection.send_result(msg["id"], {"fired": [run.as_dict() for run in fired]})


@websocket_api.websocket_command({vol.Required("type"): "thask/trigger/undo", vol.Required("run_id"): str})
@websocket_api.require_admin
@_with_data
def ws_trigger_undo(hass, connection, msg, data: ThaskData) -> None:
    """Remove the task a run created; the trigger does not fire again for that day."""
    connection.send_result(msg["id"], data.triggers.undo(msg["run_id"], data.collection).as_dict())
