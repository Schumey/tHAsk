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

from .const import DOMAIN, VIEWS
from .core.assist import LANGUAGES as SENTENCE_LANGUAGES, sentences
from .core.collection import NotFoundError
from .core.models import PRIORITIES, Task
from .core.importers import FORMATS, import_file
from .core.ms_todo import ImportOptions, import_export
from .core.period import Granularity, Period, PeriodStatus
from .data import ThaskData, async_get_data
from .schema import FIXED_GRANULARITIES

SERVICE_ADD_TASK = "add_task"
SERVICE_GET_TASKS = "get_tasks"
SERVICE_COMPLETE_TASK = "complete_task"
SERVICE_IMPORT_MS_TODO = "import_ms_todo"
SERVICE_CLEAR_COMPLETED = "clear_completed"
SERVICE_IMPORT_TASKS = "import_tasks"
SERVICE_INSTALL_SENTENCES = "install_sentences"

DUE_FILTERS = ["today", "this_week", "this_month", "overdue", "all"]

ADD_TASK_SCHEMA = vol.Schema(
    {
        vol.Optional(ATTR_ENTITY_ID): cv.entity_id,
        vol.Required("title"): vol.All(cv.string, vol.Length(min=1)),
        vol.Optional("notes", default=""): cv.string,
        vol.Optional("due_granularity"): vol.In(FIXED_GRANULARITIES),
        # Name of a custom period ("X-Block"): due in the next one its rule found.
        vol.Optional("due_period"): cv.string,
        vol.Optional("due_date"): cv.date,
        vol.Optional("priority", default=0): vol.All(vol.Coerce(int), vol.In(PRIORITIES)),
        # Deprecated (the former "My Day"): due today unless a due date is given.
        vol.Optional("my_day", default=False): cv.boolean,
    }
)

def _one_entity_id(value: Any) -> str:
    """One entity id, also as a list of one: Home Assistant makes a list of an action's target."""
    if isinstance(value, list):
        if len(value) != 1:
            raise vol.Invalid("Exactly one entity")
        value = value[0]
    return cv.entity_id(value)


GET_TASKS_SCHEMA = vol.Schema(
    {
        vol.Optional(ATTR_ENTITY_ID): _one_entity_id,
        vol.Optional("due", default="all"): vol.In(DUE_FILTERS),
        # A smart view with the options of the web interface; a smart list's entity brings its own.
        vol.Optional("view"): vol.In(VIEWS),
        vol.Optional("include_completed", default=False): cv.boolean,
        # At most this many tasks (a small screen); "total" in the answer still counts all of them.
        vol.Optional("limit"): vol.All(vol.Coerce(int), vol.Range(min=1)),
        # Only the fields a small screen shows (id, title, priority, list, due_label, due_kind, due_days, due_time).
        vol.Optional("compact", default=False): cv.boolean,
    }
)


COMPLETE_TASK_SCHEMA = vol.Schema(
    {
        vol.Required("task_id"): cv.string,
        # False opens it again (a tap undone on a wall panel).
        vol.Optional("completed", default=True): cv.boolean,
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


INSTALL_SENTENCES_SCHEMA = vol.Schema(
    {
        vol.Optional("languages", default=list(SENTENCE_LANGUAGES)): vol.All(
            cv.ensure_list, [vol.In(SENTENCE_LANGUAGES)]
        ),
    }
)


def _write_sentences(config_dir: str, languages: list[str]) -> list[str]:
    """Write `custom_sentences/<lang>/thask.yaml`; returns the paths."""
    paths = []
    for lang in languages:
        path = Path(config_dir) / "custom_sentences" / lang / "thask.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(sentences(lang), encoding="utf-8")
        paths.append(str(path))
    return paths


async def _require_admin(hass: HomeAssistant, call: ServiceCall) -> None:
    if call.context.user_id:
        user = await hass.auth.async_get_user(call.context.user_id)
        if user is None or not user.is_admin:
            raise Unauthorized(context=call.context)


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


def _smart_view(hass: HomeAssistant, entity_id: str | None) -> str | None:
    """The view behind a smart list entity (todo.thask_mein_tag), None for any other entity."""
    if entity_id is None:
        return None
    entry = er.async_get(hass).async_get(entity_id)
    if entry is None or entry.platform != DOMAIN:
        return None
    return next((view for view in VIEWS if entry.unique_id == f"{entry.config_entry_id}_{view}"), None)


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
        if "due_period" in call.data:
            fields["due"] = data.next_custom_period(call.data["due_period"], call.data.get("due_date")).as_dict()
        elif "due_granularity" in call.data or "due_date" in call.data:
            granularity = Granularity(call.data.get("due_granularity", Granularity.DAY))
            fields["due"] = Period(granularity, call.data.get("due_date", data.today)).as_dict()
        elif call.data["my_day"]:
            fields["due"] = Period.day(data.today).as_dict()
        task = data.collection.create_task(list_id, call.data["title"], **fields)
        return data.task_info(task) if call.return_response else None

    async def get_tasks(call: ServiceCall) -> ServiceResponse:
        data = async_get_data(hass)
        entity_id = call.data.get(ATTR_ENTITY_ID)
        list_id = _list_id_for(hass, data, entity_id)
        view = call.data.get("view") or _smart_view(hass, entity_id)
        today = data.today
        tasks = [
            task
            for task in data.collection.tasks.values()
            if (list_id is None or task.list_id == list_id)
            and (call.data["include_completed"] or not task.completed)
            and _matches_due(task, call.data["due"], today)
            and (view is None or data.in_view(task, view, today))
        ]
        tasks.sort(key=lambda task: (task.due.end if task.due else date.max, -task.priority, task.position))
        total = len(tasks)
        if "limit" in call.data:
            tasks = tasks[: call.data["limit"]]
        describe = data.task_brief if call.data["compact"] else data.task_info
        return {"tasks": [describe(task) for task in tasks], "total": total}

    async def complete_task(call: ServiceCall) -> None:
        """Tick a task off (or open it again) by its id, whichever list or view it is shown in."""
        data = async_get_data(hass)
        try:
            data.collection.update_task(call.data["task_id"], {"completed": call.data["completed"]}, data.today)
        except NotFoundError:
            raise ServiceValidationError(f"Task {call.data['task_id']} not found") from None

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
        await _require_admin(hass, call)
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
        await _require_admin(hass, call)
        data = async_get_data(hass)
        path = _config_file(hass.config.config_dir, call.data["file"])
        content = await hass.async_add_executor_job(path.read_bytes)
        try:
            result = import_file(
                data.collection,
                path.name,
                content,
                fmt=call.data["format"],
                target_list=call.data.get("list"),
                include_completed=call.data["include_completed"],
                today=data.today,
                tz=data.tz,
                dry_run=call.data["dry_run"],
            )
        except ValueError as err:
            raise ServiceValidationError(f"Datei konnte nicht gelesen werden: {err}") from err
        return result.as_dict()

    hass.services.async_register(
        DOMAIN, SERVICE_ADD_TASK, add_task, schema=ADD_TASK_SCHEMA, supports_response=SupportsResponse.OPTIONAL
    )
    hass.services.async_register(
        DOMAIN, SERVICE_GET_TASKS, get_tasks, schema=GET_TASKS_SCHEMA, supports_response=SupportsResponse.ONLY
    )
    hass.services.async_register(DOMAIN, SERVICE_COMPLETE_TASK, complete_task, schema=COMPLETE_TASK_SCHEMA)
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
    async def install_sentences(call: ServiceCall) -> ServiceResponse:
        """Sentences for Assist; Home Assistant reads them only from the config directory."""
        await _require_admin(hass, call)
        paths = await hass.async_add_executor_job(
            _write_sentences, hass.config.config_dir, call.data["languages"]
        )
        if hass.services.has_service("conversation", "reload"):
            await hass.services.async_call("conversation", "reload", blocking=True)
        return {"files": paths} if call.return_response else None

    hass.services.async_register(
        DOMAIN,
        SERVICE_INSTALL_SENTENCES,
        install_sentences,
        schema=INSTALL_SENTENCES_SCHEMA,
        supports_response=SupportsResponse.OPTIONAL,
    )
    hass.services.async_register(
        DOMAIN,
        SERVICE_CLEAR_COMPLETED,
        clear_completed,
        schema=CLEAR_COMPLETED_SCHEMA,
        supports_response=SupportsResponse.OPTIONAL,
    )
