"""WebSocket API used by the tHAsk apps. All commands are prefixed with "thask/"."""

from __future__ import annotations

import base64
from collections.abc import Callable
from datetime import timedelta
from functools import partial, wraps
from typing import Any

import voluptuous as vol

from homeassistant.components import websocket_api
from homeassistant.config_entries import ConfigEntryState
from homeassistant.core import HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.util import dt as dt_util

from .core.access import ChangeFilter, check_list, check_task, visible_lists
from .const import (
    CONF_AUTO_CLEAR_DAYS,
    CONF_IMPORTANT_PRIORITY,
    CONF_HIDDEN_VIEWS,
    CONF_OVERDUE,
    CONF_REMINDER_TARGETS,
    CONF_SEPARATE_MONTH,
    CONF_SEPARATE_WEEK,
    CONF_WEEK_MODE,
    DEFAULT_OPTIONS,
    DOMAIN,
    HIDEABLE_VIEWS,
    IMPORTANT_PRIORITIES,
    OVERDUE_MODES,
    SIGNAL_DAY_CHANGED,
    SIGNAL_OPTIONS_CHANGED,
    SIGNAL_PERIODS_CHANGED,
    SIGNAL_REMINDER,
    SIGNAL_TRIGGERS_CHANGED,
    WEEK_MODES,
)
from .core.collection import Change, NotFoundError
from .core.custom_periods import PeriodRule
from .core.importers import FORMATS as IMPORT_FORMATS, import_file
from .core.models import Task, TaskList
from .core.period import Period
from .core.parser import KIND_DUE, KIND_PRIORITY, KIND_RECURRENCE, KIND_TIME, parse
from .core.triggers import Trigger
from .data import ThaskData, async_get_data
from .schema import (
    LIST_FIELDS,
    PERIOD_RULE_FIELDS,
    PERIOD_SCHEMA,
    PERIOD_RULE_NAME,
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
        ws_task_occurrence,
        ws_parse,
        ws_triggers_subscribe,
        ws_trigger_create,
        ws_trigger_update,
        ws_trigger_delete,
        ws_trigger_test,
        ws_trigger_run,
        ws_trigger_check,
        ws_trigger_undo,
        ws_options_get,
        ws_options_update,
        ws_users,
        ws_attachment_delete,
        ws_period_rules_get,
        ws_period_rule_create,
        ws_period_rule_update,
        ws_period_rule_delete,
        ws_period_rules_refresh,
        ws_import,
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


def _snapshot(data: ThaskData, connection: websocket_api.ActiveConnection) -> dict[str, Any]:
    # Lists with members only reach those users (and administrators), see access.py.
    lists = visible_lists(connection.user, data.collection)
    list_ids = {task_list.id for task_list in lists}
    return {
        "today": data.today.isoformat(),
        "me": connection.user.id if connection.user else None,
        "options": data.options,
        "lists": [task_list.as_dict() for task_list in lists],
        "tasks": [task.as_dict() for task in data.collection.tasks.values() if task.list_id in list_ids],
        # Custom periods ("X block") with the periods their rules found.
        "periods": data.periods.public(data.today),
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
    connection.send_result(msg["id"], _snapshot(data, connection))


@websocket_api.websocket_command({vol.Required("type"): "thask/subscribe"})
@_with_data
def ws_subscribe(hass, connection, msg, data: ThaskData) -> None:
    """Send a snapshot, then every change and a notice when the day changes.

    Only lists the user may see and their tasks are sent. When a list becomes visible or invisible for
    the user (its members changed), a fresh snapshot replaces everything instead of single changes.
    """
    changes = ChangeFilter(connection.user, data.collection)

    @callback
    def forward_change(change: Change) -> None:
        result = changes.apply(change)
        if result == ChangeFilter.RESNAPSHOT:
            changes.reset()
            connection.send_message(
                websocket_api.event_message(msg["id"], {"type": "snapshot", **_snapshot(data, connection)})
            )
        elif isinstance(result, Change):
            connection.send_message(websocket_api.event_message(msg["id"], {"type": "change", **result.as_dict()}))

    @callback
    def forward_day_changed() -> None:
        connection.send_message(
            websocket_api.event_message(msg["id"], {"type": "day_changed", "today": data.today.isoformat()})
        )

    @callback
    def forward_options() -> None:
        connection.send_message(websocket_api.event_message(msg["id"], {"type": "options", **data.options}))

    @callback
    def forward_periods() -> None:
        connection.send_message(
            websocket_api.event_message(msg["id"], {"type": "periods", "periods": data.periods.public(data.today)})
        )

    @callback
    def forward_reminder(info: dict[str, Any]) -> None:
        # The desktop app shows these as notifications; only for tasks the user may see.
        task = data.collection.tasks.get(info.get("id", ""))
        if task is None or task.list_id not in changes.visible:
            return
        connection.send_message(websocket_api.event_message(msg["id"], {"type": "reminder", "task": info}))

    unsubs = [
        data.collection.subscribe(forward_change),
        async_dispatcher_connect(hass, SIGNAL_DAY_CHANGED, forward_day_changed),
        async_dispatcher_connect(hass, SIGNAL_OPTIONS_CHANGED, forward_options),
        async_dispatcher_connect(hass, SIGNAL_REMINDER, forward_reminder),
        async_dispatcher_connect(hass, SIGNAL_PERIODS_CHANGED, forward_periods),
    ]

    @callback
    def unsubscribe() -> None:
        for unsub in unsubs:
            unsub()

    connection.subscriptions[msg["id"]] = unsubscribe
    connection.send_result(msg["id"])
    connection.send_message(websocket_api.event_message(msg["id"], {"type": "snapshot", **_snapshot(data, connection)}))


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
    check_list(connection.user, data.collection, msg["list_id"])
    task_list = data.collection.update_list(msg["list_id"], _patch(msg, TaskList.EDITABLE))
    connection.send_result(msg["id"], task_list.as_dict())


@websocket_api.websocket_command({vol.Required("type"): "thask/list/delete", vol.Required("list_id"): str})
@_with_data
def ws_list_delete(hass, connection, msg, data: ThaskData) -> None:
    check_list(connection.user, data.collection, msg["list_id"])
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
    check_list(connection.user, data.collection, msg["list_id"])
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
    if msg.get("list_id"):
        check_list(connection.user, data.collection, msg["list_id"])
        removed = data.collection.clear_completed(msg["list_id"], before)
    elif connection.user is None or connection.user.is_admin:
        removed = data.collection.clear_completed(None, before)
    else:
        # "All lists" means all lists this user may change.
        removed = sum(
            data.collection.clear_completed(task_list.id, before)
            for task_list in visible_lists(connection.user, data.collection)
        )
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
    check_list(connection.user, data.collection, fields["list_id"])
    task = data.collection.create_task(fields.pop("list_id"), fields.pop("title"), **fields)
    connection.send_result(msg["id"], task.as_dict())


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/task/update", vol.Required("task_id"): str, **TASK_FIELDS}
)
@_with_data
def ws_task_update(hass, connection, msg, data: ThaskData) -> None:
    check_task(connection.user, data.collection, msg["task_id"])
    if "list_id" in msg:
        check_list(connection.user, data.collection, msg["list_id"])
    task = data.collection.update_task(msg["task_id"], _patch(msg, Task.EDITABLE), data.today)
    connection.send_result(msg["id"], task.as_dict())


@websocket_api.websocket_command({vol.Required("type"): "thask/task/delete", vol.Required("task_id"): str})
@_with_data
def ws_task_delete(hass, connection, msg, data: ThaskData) -> None:
    check_task(connection.user, data.collection, msg["task_id"])
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
    check_task(connection.user, data.collection, msg["task_id"])
    task = data.collection.move_task(msg["task_id"], msg.get("previous_id"))
    connection.send_result(msg["id"], task.as_dict())


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/task/occurrence",
        vol.Required("task_id"): str,
        # Due period of the coming occurrence, as the clients project it.
        vol.Required("due"): PERIOD_SCHEMA,
        vol.Required("done"): bool,
    }
)
@_with_data
def ws_task_occurrence(hass, connection, msg, data: ThaskData) -> None:
    """Tick off (or untick) a coming occurrence of a recurring task ahead of time."""
    check_task(connection.user, data.collection, msg["task_id"])
    try:
        occurrence = data.collection.set_occurrence(
            msg["task_id"], Period.from_dict(msg["due"]), msg["done"], data.today
        )
    except ValueError as err:
        connection.send_error(msg["id"], websocket_api.ERR_INVALID_FORMAT, str(err))
        return
    connection.send_result(msg["id"], occurrence.as_dict() if occurrence else None)


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
    result = parse(msg["text"], data.today, set(msg["disabled"]), data.custom_periods())
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


def _notify_services(hass: HomeAssistant) -> list[str]:
    """Legacy notify services for reminders, as in the options flow (notify.send_message needs an entity)."""
    return sorted(service for service in hass.services.async_services_for_domain("notify") if service != "send_message")


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/attachment/delete", vol.Required("task_id"): str, vol.Required("attachment_id"): str}
)
@_with_data
def ws_attachment_delete(hass, connection, msg, data: ThaskData) -> None:
    check_task(connection.user, data.collection, msg["task_id"])
    attachment = data.collection.remove_attachment(msg["task_id"], msg["attachment_id"])
    path = data.attachments_root / msg["task_id"] / attachment.id
    hass.async_add_executor_job(partial(path.unlink, missing_ok=True))
    connection.send_result(msg["id"])


@websocket_api.websocket_command({vol.Required("type"): "thask/users"})
@websocket_api.async_response
async def ws_users(hass, connection, msg) -> None:
    """The people a list can be for: active HA users that are not system users."""
    users = [
        {"id": user.id, "name": user.name or user.id}
        for user in await hass.auth.async_get_users()
        if user.is_active and not user.system_generated
    ]
    users.sort(key=lambda user: user["name"].casefold())
    connection.send_result(msg["id"], {"me": connection.user.id if connection.user else None, "users": users})


@websocket_api.websocket_command({vol.Required("type"): "thask/options/get"})
@websocket_api.require_admin
@_with_data
def ws_options_get(hass, connection, msg, data: ThaskData) -> None:
    """All options of the integration, for the settings page of the web interface."""
    entry = next(e for e in hass.config_entries.async_entries(DOMAIN) if e.state is ConfigEntryState.LOADED)
    connection.send_result(
        msg["id"], {"options": {**DEFAULT_OPTIONS, **entry.options}, "notify_services": _notify_services(hass)}
    )


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/options/update",
        vol.Optional(CONF_OVERDUE): vol.In(OVERDUE_MODES),
        vol.Optional(CONF_SEPARATE_WEEK): bool,
        vol.Optional(CONF_SEPARATE_MONTH): bool,
        vol.Optional(CONF_WEEK_MODE): vol.In(WEEK_MODES),
        vol.Optional(CONF_HIDDEN_VIEWS): [vol.In(HIDEABLE_VIEWS)],
        vol.Optional(CONF_IMPORTANT_PRIORITY): vol.In(IMPORTANT_PRIORITIES),
        vol.Optional(CONF_AUTO_CLEAR_DAYS): vol.All(vol.Coerce(int), vol.Range(min=0, max=3650)),
        vol.Optional(CONF_REMINDER_TARGETS): [str],
    }
)
@websocket_api.require_admin
@_with_data
def ws_options_update(hass, connection, msg, data: ThaskData) -> None:
    """Change options, the same as the options flow; the update listener applies them and tells the apps."""
    entry = next(e for e in hass.config_entries.async_entries(DOMAIN) if e.state is ConfigEntryState.LOADED)
    patch = {key: value for key, value in msg.items() if key not in ("type", "id")}
    options = {**DEFAULT_OPTIONS, **entry.options, **patch}
    hass.config_entries.async_update_entry(entry, options=options)
    connection.send_result(msg["id"], {"options": options})


# -- custom periods -------------------------------------------------------------------------------


def _period_rules(data: ThaskData) -> dict[str, Any]:
    """Rules with everything they found and the errors of the last refresh, for the settings page."""
    return {
        "rules": [
            {
                **rule.as_dict(),
                "instances": [period.as_dict() for period in data.periods.upcoming(rule.id, data.today)],
                "error": data.periods.errors.get(rule.id),
                "diagnosis": data.periods.diagnosis(rule.id),
            }
            for rule in data.periods.sorted_rules()
        ]
    }


@websocket_api.websocket_command({vol.Required("type"): "thask/period_rules/get"})
@websocket_api.require_admin
@_with_data
def ws_period_rules_get(hass, connection, msg, data: ThaskData) -> None:
    connection.send_result(msg["id"], _period_rules(data))


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/period_rule/create",
        **{key: value for key, value in PERIOD_RULE_FIELDS.items() if key != "name"},
        vol.Required("name"): PERIOD_RULE_NAME,
    }
)
@websocket_api.require_admin
@_async_with_data
async def ws_period_rule_create(hass, connection, msg, data: ThaskData) -> None:
    """Add a rule and look it up in its calendar at once; answers with all rules."""
    rule = data.periods.create(_patch(msg, PeriodRule.EDITABLE))
    await data.async_refresh_periods(rule_ids=[rule.id])
    connection.send_result(msg["id"], {**_period_rules(data), "rule_id": rule.id})


@websocket_api.websocket_command(
    {vol.Required("type"): "thask/period_rule/update", vol.Required("rule_id"): str, **PERIOD_RULE_FIELDS}
)
@websocket_api.require_admin
@_async_with_data
async def ws_period_rule_update(hass, connection, msg, data: ThaskData) -> None:
    data.periods.update(msg["rule_id"], _patch(msg, PeriodRule.EDITABLE))
    await data.async_refresh_periods(rule_ids=[msg["rule_id"]])
    connection.send_result(msg["id"], _period_rules(data))


@websocket_api.websocket_command({vol.Required("type"): "thask/period_rule/delete", vol.Required("rule_id"): str})
@websocket_api.require_admin
@_with_data
def ws_period_rule_delete(hass, connection, msg, data: ThaskData) -> None:
    data.periods.delete(msg["rule_id"])
    connection.send_result(msg["id"], _period_rules(data))


@websocket_api.websocket_command({vol.Required("type"): "thask/period_rules/refresh"})
@websocket_api.require_admin
@_async_with_data
async def ws_period_rules_refresh(hass, connection, msg, data: ThaskData) -> None:
    """Look all rules up in their calendars now."""
    await data.async_refresh_periods(rule_ids=list(data.periods.rules))
    connection.send_result(msg["id"], _period_rules(data))


# -- import ---------------------------------------------------------------------------------------

# A chosen file arrives base64 encoded in one message (Home Assistant allows about 4 MB per message).
IMPORT_MAX_BASE64 = 3_000_000


@websocket_api.websocket_command(
    {
        vol.Required("type"): "thask/import",
        vol.Required("name"): vol.All(str, vol.Length(min=1, max=255)),
        vol.Required("data"): vol.All(str, vol.Length(max=IMPORT_MAX_BASE64)),
        vol.Optional("format", default="auto"): vol.In(IMPORT_FORMATS),
        # True only counts what would happen (the preview); False writes it.
        vol.Optional("dry_run", default=True): bool,
    }
)
@websocket_api.require_admin
@_async_with_data
async def ws_import(hass, connection, msg, data: ThaskData) -> None:
    """Import a task file (checklists, Todoist, Google Tasks, ...): a preview with `dry_run`, otherwise for real."""
    try:
        content = base64.b64decode(msg["data"], validate=True)
    except ValueError as err:
        raise HomeAssistantError(f"Die Datei konnte nicht übertragen werden: {err}") from err
    try:
        result = import_file(
            data.collection,
            msg["name"],
            content,
            fmt=msg["format"],
            today=data.today,
            tz=data.tz,
            dry_run=msg["dry_run"],
        )
    except ValueError as err:
        raise HomeAssistantError(f"Datei konnte nicht gelesen werden: {err}") from err
    connection.send_result(msg["id"], result.as_dict())
