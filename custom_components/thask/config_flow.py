"""Config flow for tHAsk."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.config_entries import ConfigEntry, ConfigFlow, ConfigFlowResult, OptionsFlow
from homeassistant.core import callback
from homeassistant.helpers.selector import SelectSelector, SelectSelectorConfig, SelectSelectorMode

from .const import CONF_OVERDUE, CONF_REMINDER_TARGETS, DEFAULT_OVERDUE, DOMAIN, OVERDUE_MODES


class ThaskConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> ThaskOptionsFlow:
        return ThaskOptionsFlow()

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(title="tHAsk", data={})
        return self.async_show_form(step_id="user")


class ThaskOptionsFlow(OptionsFlow):
    async def async_step_init(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(data=user_input)
        options = self.config_entry.options
        # Legacy notify services such as mobile_app_<phone> or persistent_notification;
        # notify.send_message needs an entity and is left out.
        services = sorted(s for s in self.hass.services.async_services_for_domain("notify") if s != "send_message")
        targets = options.get(CONF_REMINDER_TARGETS, [])
        schema = vol.Schema(
            {
                vol.Required(CONF_OVERDUE, default=options.get(CONF_OVERDUE, DEFAULT_OVERDUE)): SelectSelector(
                    SelectSelectorConfig(
                        options=list(OVERDUE_MODES), translation_key=CONF_OVERDUE, mode=SelectSelectorMode.LIST
                    )
                ),
                vol.Optional(CONF_REMINDER_TARGETS, default=targets): SelectSelector(
                    SelectSelectorConfig(
                        # Keep targets whose service is gone (phone removed) visible, so they can be unticked.
                        options=sorted({*services, *targets}),
                        multiple=True,
                        mode=SelectSelectorMode.LIST,
                    )
                ),
            }
        )
        return self.async_show_form(step_id="init", data_schema=schema)
