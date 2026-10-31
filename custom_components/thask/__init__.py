"""tHAsk: local task management with fuzzy due dates for Home Assistant."""

from __future__ import annotations

from pathlib import Path

from homeassistant.components import frontend, panel_custom
from homeassistant.components.http import StaticPathConfig
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.typing import ConfigType
from homeassistant.loader import async_get_integration

from .const import DOMAIN, PANEL_STATIC_URL, PANEL_URL_PATH
from .data import ThaskData
from .services import async_setup_services
from .websocket_api import async_register_websocket_commands

PLATFORMS = [Platform.TODO]

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)

type ThaskConfigEntry = ConfigEntry[ThaskData]


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async_register_websocket_commands(hass)
    async_setup_services(hass)
    await hass.http.async_register_static_paths(
        [StaticPathConfig(PANEL_STATIC_URL, str(Path(__file__).parent / "www"), cache_headers=False)]
    )
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ThaskConfigEntry) -> bool:
    data = ThaskData(hass)
    data.set_options(entry.options)
    await data.async_start()
    entry.runtime_data = data
    entry.async_on_unload(entry.add_update_listener(_async_options_updated))
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)

    integration = await async_get_integration(hass, DOMAIN)
    # The dashboard card is loaded on every page, so `custom:thask-card` works without adding a resource.
    card_url = f"{PANEL_STATIC_URL}/thask-card.js?v={integration.version}"
    frontend.add_extra_js_url(hass, card_url)
    entry.async_on_unload(lambda: frontend.remove_extra_js_url(hass, card_url))
    await panel_custom.async_register_panel(
        hass,
        frontend_url_path=PANEL_URL_PATH,
        webcomponent_name="thask-panel",
        sidebar_title="tHAsk",
        sidebar_icon="mdi:checkbox-marked-circle-outline",
        # The version busts the browser cache after updates.
        module_url=f"{PANEL_STATIC_URL}/thask-panel.js?v={integration.version}",
    )
    return True


async def _async_options_updated(hass: HomeAssistant, entry: ThaskConfigEntry) -> None:
    """Options apply at once, without a reload that would cut off the apps' subscriptions."""
    entry.runtime_data.set_options(entry.options)


async def async_unload_entry(hass: HomeAssistant, entry: ThaskConfigEntry) -> bool:
    if unloaded := await hass.config_entries.async_unload_platforms(entry, PLATFORMS):
        frontend.async_remove_panel(hass, PANEL_URL_PATH, warn_if_unknown=False)
        await entry.runtime_data.async_stop()
    return unloaded
