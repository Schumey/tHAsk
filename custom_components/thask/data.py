"""Runtime data: persistence, reminders and day change handling around the task collection."""

from __future__ import annotations

from datetime import date, datetime, timedelta, tzinfo
from functools import partial
from typing import Any

from homeassistant.config_entries import ConfigEntryState
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import (
    async_track_point_in_utc_time,
    async_track_time_change,
    async_track_time_interval,
)
from homeassistant.helpers.storage import Store
from homeassistant.util import dt as dt_util

from .const import (
    DOMAIN,
    EVENT_REMINDER,
    EVENT_TASK_DUE,
    EVENT_TASK_OVERDUE,
    EVENT_TRIGGER_FIRED,
    SAVE_DELAY,
    SIGNAL_DAY_CHANGED,
    SIGNAL_TRIGGERS_CHANGED,
    STORAGE_KEY,
    STORAGE_KEY_TRIGGERS,
    STORAGE_VERSION,
    TRIGGER_INTERVAL_SECONDS,
)
from .core.collection import Change, TaskCollection
from .core.models import Task
from .core.triggers import Evaluator, Match, TriggerBook, TriggerRun
from .trigger_source import HassSource


@callback
def async_get_data(hass: HomeAssistant) -> ThaskData:
    """The data of the loaded tHAsk entry (there is only one)."""
    for entry in hass.config_entries.async_entries(DOMAIN):
        if entry.state is ConfigEntryState.LOADED:
            return entry.runtime_data
    raise HomeAssistantError("tHAsk is not loaded")


class ThaskData:
    def __init__(self, hass: HomeAssistant) -> None:
        self.hass = hass
        self.collection = TaskCollection()
        self._store: Store[dict[str, Any]] = Store(hass, STORAGE_VERSION, STORAGE_KEY)
        self.triggers = TriggerBook()
        self._trigger_store: Store[dict[str, Any]] = Store(hass, STORAGE_VERSION, STORAGE_KEY_TRIGGERS)
        self._trigger_source = HassSource(hass)
        self.last_trigger_check: datetime | None = None
        self._checking = False
        self._reminders: dict[str, CALLBACK_TYPE] = {}
        self._unsubs: list[CALLBACK_TYPE] = []

    @property
    def tz(self) -> tzinfo:
        return dt_util.get_default_time_zone()

    @property
    def today(self) -> date:
        return dt_util.now().date()

    @property
    def language(self) -> str:
        return self.hass.config.language or "en"

    async def async_start(self) -> None:
        if data := await self._store.async_load():
            self.collection.load(data)
        if not self.collection.lists:
            self.collection.create_list("Aufgaben" if self.language.startswith("de") else "Tasks")
            await self._store.async_save(self.collection.dump())
        self._unsubs.append(self.collection.subscribe(self._on_change))
        self._unsubs.append(
            async_track_time_change(self.hass, self._on_new_day, hour=0, minute=0, second=5)
        )
        for task in self.collection.tasks.values():
            self._schedule_reminder(task)

        if data := await self._trigger_store.async_load():
            self.triggers.load(data)
        self._unsubs.append(self.triggers.subscribe(self._on_triggers_change))
        self._unsubs.append(
            async_track_time_interval(
                self.hass, self.async_check_triggers, timedelta(seconds=TRIGGER_INTERVAL_SECONDS)
            )
        )

    async def async_stop(self) -> None:
        for unsub in [*self._unsubs, *self._reminders.values()]:
            unsub()
        self._unsubs.clear()
        self._reminders.clear()
        await self._store.async_save(self.collection.dump())
        await self._trigger_store.async_save(self.triggers.dump())

    # -- triggers --------------------------------------------------------------------------

    @callback
    def _on_triggers_change(self) -> None:
        self._trigger_store.async_delay_save(self.triggers.dump, SAVE_DELAY)
        async_dispatcher_send(self.hass, SIGNAL_TRIGGERS_CHANGED)

    def trigger_status(self) -> dict[str, Any]:
        return {
            "last_check": self.last_trigger_check.isoformat() if self.last_trigger_check else None,
            "errors": self.triggers.errors,
        }

    async def async_check_triggers(self, _now: datetime | None = None) -> list[TriggerRun]:
        """Fire the triggers that apply now (runs every minute)."""
        if self._checking:
            return []
        self._checking = True
        try:
            now = dt_util.now()
            fired = await self.triggers.check(self.collection, self._trigger_source, now, self.language)
            self.last_trigger_check = now
        finally:
            self._checking = False
        for run in fired:
            self._announce_run(run)
        async_dispatcher_send(self.hass, SIGNAL_TRIGGERS_CHANGED)
        return fired

    async def async_test_trigger(self, trigger_id: str) -> Match:
        """Judge a trigger's conditions for today without creating anything."""
        trigger = self.triggers.get(trigger_id)
        days = trigger.target_days(self.today)
        evaluator = Evaluator(self._trigger_source, dt_util.now())
        for day in days:
            match = await evaluator.evaluate(trigger, day, days[-1])
            if match.met:
                return match
        return await evaluator.evaluate(trigger, days[0], days[-1])

    def run_trigger_now(self, trigger_id: str) -> TriggerRun:
        """Create the trigger's task for today, whether its conditions apply or not."""
        trigger = self.triggers.get(trigger_id)
        run = self.triggers.fire(trigger, self.collection, self.today, self.today, self.language, manual=True)
        self._announce_run(run)
        return run

    @callback
    def _announce_run(self, run: TriggerRun) -> None:
        trigger = self.triggers.triggers.get(run.trigger_id)
        task = self.collection.tasks.get(run.task_id or "")
        self.hass.bus.async_fire(
            EVENT_TRIGGER_FIRED,
            {
                "trigger_id": run.trigger_id,
                "trigger_name": trigger.name if trigger else None,
                "day": run.day,
                "task": self.task_info(task) if task else None,
            },
        )

    def task_info(self, task: Task) -> dict[str, Any]:
        """Task data enriched with labels, for events, service responses and attributes."""
        task_list = self.collection.lists.get(task.list_id)
        info = task.as_dict()
        info["list_name"] = task_list.name if task_list else None
        info["due_label"] = task.due.label(self.language, self.today) if task.due else None
        info["due_end"] = task.due.end.isoformat() if task.due else None
        info["due_status"] = task.due.status(self.today).value if task.due else None
        return info

    @callback
    def _on_change(self, change: Change) -> None:
        self._store.async_delay_save(self.collection.dump, SAVE_DELAY)
        if change.kind != "task":
            return
        if change.action == "removed":
            if unsub := self._reminders.pop(change.id, None):
                unsub()
        else:
            self._schedule_reminder(self.collection.tasks[change.id])

    @callback
    def _schedule_reminder(self, task: Task) -> None:
        if unsub := self._reminders.pop(task.id, None):
            unsub()
        if task.completed or not task.reminder:
            return
        when = dt_util.parse_datetime(task.reminder)
        if when is None or when <= dt_util.utcnow():
            return
        self._reminders[task.id] = async_track_point_in_utc_time(
            self.hass, partial(self._fire_reminder, task.id), when
        )

    @callback
    def _fire_reminder(self, task_id: str, _now: datetime) -> None:
        self._reminders.pop(task_id, None)
        task = self.collection.tasks.get(task_id)
        if task and not task.completed:
            self.hass.bus.async_fire(EVENT_REMINDER, self.task_info(task))

    @callback
    def _on_new_day(self, _now: datetime) -> None:
        today = self.today
        yesterday = today - timedelta(days=1)
        for task in self.collection.tasks.values():
            if task.completed or task.due is None:
                continue
            if task.due.start == today:
                self.hass.bus.async_fire(EVENT_TASK_DUE, self.task_info(task))
            elif task.due.end == yesterday:
                self.hass.bus.async_fire(EVENT_TASK_OVERDUE, self.task_info(task))
        async_dispatcher_send(self.hass, SIGNAL_DAY_CHANGED)
