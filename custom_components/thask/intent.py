"""Assist intents: "Was ist diese Woche fällig?" and "Neue Aufgabe Steuer KW 47".

The handlers also serve AI conversation agents (through the Assist API); the sentences for the built-in agent come
from `custom_sentences`, see `core/assist.py`.
"""

from __future__ import annotations

import voluptuous as vol

from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers import intent

from .core.assist import (
    INTENT_ADD,
    INTENT_DUE,
    PERIODS,
    added_answer,
    due_answer,
    due_tasks,
    split_list,
)
from .core.parser import parse
from .data import async_get_data


@callback
def async_register_intents(hass: HomeAssistant) -> None:
    intent.async_register(hass, DueTasksIntent())
    intent.async_register(hass, AddTaskIntent())


class DueTasksIntent(intent.IntentHandler):
    intent_type = INTENT_DUE
    description = "Lists the open tHAsk tasks due today, this week, this month or overdue"
    slot_schema = {vol.Required("period"): vol.In(PERIODS)}

    async def async_handle(self, intent_obj: intent.Intent) -> intent.IntentResponse:
        slots = self.async_validate_slots(intent_obj.slots)
        period = slots["period"]["value"]
        data = async_get_data(intent_obj.hass)
        tasks = due_tasks(data.collection.tasks.values(), period, data.today, rolling=data.week_mode == "rolling")
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
        text, task_list = split_list(intent_obj.language, slots["task"]["value"], data.collection.lists.values())
        if task_list is None and (task_list := data.collection.default_list()) is None:
            raise intent.IntentHandleError("There is no task list to add the task to")
        result = parse(text, data.today)
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
