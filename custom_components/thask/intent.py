"""Assist intents: "Was ist diese Woche fällig?" and "Neue Aufgabe Steuer KW 47".

The handlers also serve AI conversation agents (through the Assist API); the sentences for the built-in agent come
from `custom_sentences`, see `core/assist.py`.
"""

from __future__ import annotations

import voluptuous as vol

from homeassistant.core import HomeAssistant
from homeassistant.helpers import intent

from .core.access import visible_lists
from .core.assist import (
    INTENT_ADD,
    INTENT_DUE,
    PERIODS,
    added_answer,
    due_answer,
    due_tasks,
    split_list,
)
from .core.models import TaskList
from .core.parser import parse
from .data import ThaskData, async_get_data


async def async_setup_intents(hass: HomeAssistant) -> None:
    """Called by Home Assistant's intent integration, which loads this file as the intent platform."""
    intent.async_register(hass, DueTasksIntent())
    intent.async_register(hass, AddTaskIntent())


def _visible_lists(data: ThaskData, intent_obj: intent.Intent) -> list[TaskList]:
    user_id = intent_obj.context.user_id if intent_obj.context else None
    return [task_list for task_list in data.collection.sorted_lists() if task_list.visible_to(user_id)]


class DueTasksIntent(intent.IntentHandler):
    intent_type = INTENT_DUE
    description = "Lists the open tHAsk tasks due today, this week, this month or overdue"
    slot_schema = {vol.Required("period"): vol.In(PERIODS)}

    async def async_handle(self, intent_obj: intent.Intent) -> intent.IntentResponse:
        slots = self.async_validate_slots(intent_obj.slots)
        period = slots["period"]["value"]
        data = async_get_data(intent_obj.hass)
        # Only the lists of the person asking, if Assist knows who it is.
        mine = _visible_lists(data, intent_obj)
        tasks = due_tasks(
            (task for task in data.collection.tasks.values() if task.list_id in {item.id for item in mine}),
            period,
            data.today,
            rolling=data.week_mode == "rolling",
        )
        response = intent_obj.create_response()
        response.response_type = intent.IntentResponseType.QUERY_ANSWER
        response.async_set_speech(due_answer(intent_obj.language, period, tasks))
        return response


class AddTaskIntent(intent.IntentHandler):
    intent_type = INTENT_ADD
    description = (
        "Adds a tHAsk task. The text may contain a fuzzy due date (e.g. 'week 47', 'next month'), "
        "a time, a recurrence and 'to the list <name>'"
    )
    slot_schema = {vol.Required("task"): intent.non_empty_string}

    async def async_handle(self, intent_obj: intent.Intent) -> intent.IntentResponse:
        slots = self.async_validate_slots(intent_obj.slots)
        data = async_get_data(intent_obj.hass)
        mine = _visible_lists(data, intent_obj)
        user_id = intent_obj.context.user_id if intent_obj.context else None
        user = await intent_obj.hass.auth.async_get_user(user_id) if user_id else None
        # Only lists this person may change (administrators: all), see access.py.
        allowed = visible_lists(user, data.collection)
        text, task_list = split_list(intent_obj.language, slots["task"]["value"], allowed)
        if task_list is None:
            task_list = mine[0] if mine else next(iter(allowed), None)
        if task_list is None:
            raise intent.IntentHandleError("There is no task list to add the task to")
        result = parse(text, data.today, custom=data.custom_periods())
        fields = {"priority": result.priority}
        if result.due:
            fields["due"] = result.due.as_dict()
        if result.due_time:
            fields["due_time"] = result.due_time
        if result.recurrence:
            fields["recurrence"] = result.recurrence.as_dict()
        task = data.collection.create_task(task_list.id, result.title or text, **fields)
        due_label = task.due.label(intent_obj.language or data.language, data.today) if task.due else None
        response = intent_obj.create_response()
        response.response_type = intent.IntentResponseType.ACTION_DONE
        response.async_set_speech(added_answer(intent_obj.language, task.title, task_list.name, due_label))
        return response
