"""Services: add tasks with fuzzy due dates, query tasks and import from Microsoft To Do and other apps."""

from __future__ import annotations

from datetime import date, timedelta
import json
from pathlib import Path
from typing import Any

import voluptuous as vol

from homeassistant.const import ATTR_ENTITY_ID
from homeassistant.core import HomeAssistant, ServiceCall, ServiceResponse, SupportsResponse, callback
from homeassistant.exceptions import ServiceValidationError, Unauthorized
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers import entity_registry as er
from homeassistant.util import dt as dt_util

from .const import DOMAIN
from .core.models import PRIORITIES, Task
from .core.importers import FORMATS, merge_lists, read_export
from .core.ms_todo import ImportOptions, ImportResult, import_export
from .core.period import Granularity, Period, PeriodStatus
from .data import ThaskData, async_get_data
from .schema import GRANULARITIES

SERVICE_ADD_TASK = "add_task"
SERVICE_GET_TASKS = "get_tasks"
SERVICE_IMPORT_MS_TODO = "import_ms_todo"
SERVICE_CLEAR_COMPLETED = "clear_completed"
SERVICE_IMPORT_TASKS = "import_tasks"

DUE_FILTERS = ["today", "this_week", "this_month", "overdue", "all"]

ADD_TASK_SCHEMA = vol.Schema(
    {
        vol.Optional(ATTR_ENTITY_ID): cv.entity_id,
        vol.Required("title"): vol.All(cv.string, vol.Length(min=1)),
        vol.Optional("notes", default=""): cv.string,
        vol.Optional("due_granularity"): vol.In(GRANULARITIES),
        vol.Optional("due_date"): cv.date,
        vol.Optional("priority", default=0): vol.All(vol.Coerce(int), vol.In(PRIORITIES)),
        # Deprecated (the former "My Day"): due today unless a due date is given.
        vol.Optional("my_day", default=False): cv.boolean,
    }
)

GET_TASKS_SCHEMA = vol.Schema(
    {
        vol.Optional(ATTR_ENTITY_ID): cv.entity_id,
        vol.Optional("due", default="all"): vol.In(DUE_FILTERS),
        vol.Optional("include_completed", default=False): cv.boolean,
    }
)


CLEAR_COMPLETED_SCHEMA = vol.Schema(
    {
        vol.Optional(ATTR_ENTITY_ID): cv.entity_id,
        vol.Optional("older_than_days"): vol.All(vol.Coerce(int), vol.Range(min=0)),
    }
)

IMPORT_MS_TODO_SCHEMA = vol.Schema(
    {
        vol.Optional("file", default="thask_ms_todo.json"): cv.string,
        vol.Optional("dry_run", default=True): cv.boolean,
        vol.Optional("include_completed", default=True): cv.boolean,
        vol.Optional("skip_flagged_emails", default=True): cv.boolean,
        vol.Optional("convert_month_ends", default=False): cv.boolean,
        vol.Optional("convert_sundays", default=False): cv.boolean,
    }
)


IMPORT_TASKS_SCHEMA = vol.Schema(
    {
        vol.Required("file"): cv.string,
        vol.Optional("format", default="auto"): vol.In(FORMATS),
        vol.Optional("list"): cv.string,
        vol.Optional("dry_run", default=True): cv.boolean,
        vol.Optional("include_completed", default=True): cv.boolean,
    }
)


def _config_file(config_dir: str, file: str) -> Path:
    """A file inside the config directory; anything outside is refused."""
    root = Path(config_dir).resolve()
    path = (root / file).resolve()
    if not path.is_relative_to(root):
        raise ServiceValidationError("Die Datei muss im Home-Assistant-Konfigurationsordner liegen")
    if not path.is_file():
        raise ServiceValidationError(f"Datei nicht gefunden: {path}")
    return path


def _read_export(config_dir: str, file: str) -> dict[str, Any]:
    """Read a JSON export file from the config directory."""
    path = _config_file(config_dir, file)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except ValueError as err:
        raise ServiceValidationError(f"Datei ist kein gültiges JSON: {err}") from err


def _list_id_for(hass: HomeAssistant, data: ThaskData, entity_id: str | None) -> str | None:
    """The list behind a tHAsk list entity; None means all lists."""
    if entity_id is None:
        return None
    entry = er.async_get(hass).async_get(entity_id)
    if entry is None or entry.platform != DOMAIN:
        raise ServiceValidationError(f"{entity_id} is not a tHAsk list")
    return entry.unique_id if entry.unique_id in data.collection.lists else None


def _matches_due(task: Task, due: str, today: date) -> bool:
    match due:
        case "all":
            return True
        case "overdue":
            return task.due is not None and task.due.status(today) is PeriodStatus.OVERDUE
        case "today":
            return task.due_by(today)
        case "this_week":
            return task.due_by(Period(Granularity.WEEK, today).end)
        case "this_month":
            return task.due_by(Period(Granularity.MONTH, today).end)
    return False


@callback
def async_setup_services(hass: HomeAssistant) -> None:
    async def add_task(call: ServiceCall) -> ServiceResponse:
        data = async_get_data(hass)
        list_id = _list_id_for(hass, data, call.data.get(ATTR_ENTITY_ID))
        if list_id is None:
            if (default := data.collection.default_list()) is None:
                raise ServiceValidationError("There is no task list to add the task to")
            list_id = default.id
        fields: dict[str, Any] = {"notes": call.data["notes"], "priority": call.data["priority"]}
        if "due_granularity" in call.data or "due_date" in call.data:
            granularity = Granularity(call.data.get("due_granularity", Granularity.DAY))
            fields["due"] = Period(granularity, call.data.get("due_date", data.today)).as_dict()
        elif call.data["my_day"]:
            fields["due"] = Period.day(data.today).as_dict()
        task = data.collection.create_task(list_id, call.data["title"], **fields)
        return data.task_info(task) if call.return_response else None

    async def get_tasks(call: ServiceCall) -> ServiceResponse:
        data = async_get_data(hass)
        list_id = _list_id_for(hass, data, call.data.get(ATTR_ENTITY_ID))
        today = data.today
        tasks = [
            task
            for task in data.collection.tasks.values()
            if (list_id is None or task.list_id == list_id)
            and (call.data["include_completed"] or not task.completed)
            and _matches_due(task, call.data["due"], today)
        ]
        tasks.sort(key=lambda task: (task.due.end if task.due else date.max, -task.priority, task.position))
        return {"tasks": [data.task_info(task) for task in tasks]}

    async def clear_completed(call: ServiceCall) -> ServiceResponse:
        data = async_get_data(hass)
        list_id = _list_id_for(hass, data, call.data.get(ATTR_ENTITY_ID))
        if list_id is None and ATTR_ENTITY_ID in call.data:
            # A smart list would otherwise mean "all lists".
            raise ServiceValidationError("Bitte eine echte Liste wählen, keine intelligente Liste")
        before = None
        if "older_than_days" in call.data:
            before = dt_util.utcnow() - timedelta(days=call.data["older_than_days"])
        removed = data.collection.clear_completed(list_id, before)
        return {"removed": removed} if call.return_response else None

    async def import_ms_todo(call: ServiceCall) -> ServiceResponse:
        if call.context.user_id:
            user = await hass.auth.async_get_user(call.context.user_id)
            if user is None or not user.is_admin:
                raise Unauthorized(context=call.context)
        data = async_get_data(hass)
        export = await hass.async_add_executor_job(_read_export, hass.config.config_dir, call.data["file"])
        options = ImportOptions(
            include_completed=call.data["include_completed"],
            skip_flagged_emails=call.data["skip_flagged_emails"],
            convert_month_ends=call.data["convert_month_ends"],
            convert_sundays=call.data["convert_sundays"],
        )
        try:
            result = import_export(data.collection, export, options, data.tz, dry_run=call.data["dry_run"])
        except ValueError as err:
            raise ServiceValidationError(str(err)) from err
        return result.as_dict()

    async def import_tasks(call: ServiceCall) -> ServiceResponse:
        if call.context.user_id:
            user = await hass.auth.async_get_user(call.context.user_id)
            if user is None or not user.is_admin:
                raise Unauthorized(context=call.context)
        data = async_get_data(hass)
        path = _config_file(hass.config.config_dir, call.data["file"])
        content = await hass.async_add_executor_job(path.read_bytes)
        dry_run = call.data["dry_run"]
        result = ImportResult(dry_run=dry_run)
        try:
            lists = read_export(
                path.name, content, call.data["format"], call.data.get("list") or path.stem, data.today, data.tz, result
            )
        except (ValueError, KeyError) as err:
            raise ServiceValidationError(f"Datei konnte nicht gelesen werden: {err}") from err
        merge_lists(
            data.collection,
            lists,
            result,
            include_completed=call.data["include_completed"],
            target_list=call.data.get("list"),
            dry_run=dry_run,
        )
        return result.as_dict()

    hass.services.async_register(
        DOMAIN, SERVICE_ADD_TASK, add_task, schema=ADD_TASK_SCHEMA, supports_response=SupportsResponse.OPTIONAL
    )
    hass.services.async_register(
        DOMAIN, SERVICE_GET_TASKS, get_tasks, schema=GET_TASKS_SCHEMA, supports_response=SupportsResponse.ONLY
    )
    hass.services.async_register(
        DOMAIN,
        SERVICE_IMPORT_MS_TODO,
        import_ms_todo,
        schema=IMPORT_MS_TODO_SCHEMA,
        supports_response=SupportsResponse.ONLY,
    )
    hass.services.async_register(
        DOMAIN,
        SERVICE_IMPORT_TASKS,
        import_tasks,
        schema=IMPORT_TASKS_SCHEMA,
        supports_response=SupportsResponse.ONLY,
    )
    hass.services.async_register(
        DOMAIN,
        SERVICE_CLEAR_COMPLETED,
        clear_completed,
        schema=CLEAR_COMPLETED_SCHEMA,
        supports_response=SupportsResponse.OPTIONAL,
    )
