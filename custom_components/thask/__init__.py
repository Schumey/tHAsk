"""tHAsk: local task management with fuzzy due dates for Home Assistant."""

from __future__ import annotations

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.typing import ConfigType

from .const import DOMAIN
from .data import ThaskData
from .services import async_setup_services
from .websocket_api import async_register_websocket_commands

PLATFORMS = [Platform.TODO]

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)

type ThaskConfigEntry = ConfigEntry[ThaskData]


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async_register_websocket_commands(hass)
    async_setup_services(hass)
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ThaskConfigEntry) -> bool:
    data = ThaskData(hass)
    await data.async_start()
    entry.runtime_data = data
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ThaskConfigEntry) -> bool:
    if unloaded := await hass.config_entries.async_unload_platforms(entry, PLATFORMS):
        await entry.runtime_data.async_stop()
    return unloaded
