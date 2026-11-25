"""Run the exported arrival script with real HA target expansion, no device I/O."""

import json
import sys
import tempfile
import unittest
from unittest.mock import patch

from homeassistant import bootstrap, loader
from homeassistant.config_entries import ConfigEntries, ConfigEntry
from homeassistant.core import Context, HomeAssistant
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers import area_registry, config_validation as cv
from homeassistant.helpers import device_registry, entity_registry
from homeassistant.helpers.script import Script, async_validate_actions_config
from homeassistant.helpers.service import async_extract_entity_ids


with open(sys.argv.pop(1)) as config_file:
    CONFIG = json.load(config_file)


class PuraArrivalTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.hass = HomeAssistant(directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        self.hass.config_entries = ConfigEntries(self.hass, {})
        self.assertTrue(await bootstrap.async_load_base_functionality(self.hass))
        areas = area_registry.async_get(self.hass)
        entryway = areas.async_create("Entryway")
        living_room = areas.async_create("Living Room")
        self.entities = entity_registry.async_get(self.hass)
        devices = device_registry.async_get(self.hass)
        self.diffuser = None
        for domain, area, entity_domain, object_id in (
            ("pura", entryway, "binary_sensor", "entryway_diffuser_connected"),
            ("fixture", living_room, "light", "unrelated_lamp"),
        ):
            entry = ConfigEntry(
                domain=domain, title=domain, data={}, options={}, source="user",
                unique_id=None, version=1, minor_version=1, discovery_keys={}, subentries_data=[],
            )
            with patch.object(self.hass.config_entries, "async_setup", return_value=True):
                await self.hass.config_entries.async_add(entry)
            device = devices.async_get_or_create(
                config_entry_id=entry.entry_id, identifiers={(domain, object_id)},
                serial_number=object_id,
            )
            devices.async_update_device(device.id, area_id=area.id)
            entity = self.entities.async_get_or_create(
                entity_domain, domain, object_id, suggested_object_id=object_id,
                config_entry=entry, device_id=device.id,
            )
            self.hass.states.async_set(entity.entity_id, "on")
            if domain == "pura":
                self.diffuser = device.id

        async def start_timer(call):
            # Pura resolves entities to devices before talking to its cloud client.
            referenced = await async_extract_entity_ids(call)
            selected = {
                entry.device_id for entity_id in referenced
                if (entry := self.entities.async_get(entity_id)) is not None
            }
            if self.diffuser not in selected:
                raise HomeAssistantError("No valid Pura devices were targeted")
            self.hass.states.async_set("sensor.fixture_diffuser_timer", "running", {
                "intensity": call.data["intensity"],
                "duration_seconds": cv.positive_time_period(call.data["duration"]).total_seconds(),
            })

        self.hass.services.async_register("pura", "start_timer", start_timer)
        actions = await async_validate_actions_config(self.hass, cv.SCRIPT_SCHEMA(CONFIG["sequence"]))
        self.script = Script(self.hass, actions, "pura_arrive_home_freshen", "script")

    async def asyncTearDown(self):
        await self.script.async_stop()
        await self.hass.async_stop()

    async def test_arrival_starts_entryway_timer_outside_living_room(self):
        await self.script.async_run(context=Context())
        timer = self.hass.states.get("sensor.fixture_diffuser_timer")
        self.assertIsNotNone(timer)
        self.assertEqual(timer.state, "running")
        self.assertEqual(timer.attributes["intensity"], 5)
        self.assertEqual(timer.attributes["duration_seconds"], 1800)


if __name__ == "__main__":
    unittest.main()
