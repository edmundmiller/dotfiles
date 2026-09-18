"""Run Nix-exported sleep scripts in isolated HA; no physical integrations.

Pass sleep config JSON as argv[1]. The ten-minute delay is checked, then shortened.
"""

import asyncio
import copy
import json
import sys
import tempfile
import unittest

from homeassistant import bootstrap, loader
from homeassistant.core import HomeAssistant
from homeassistant.helpers.template import Template


with open(sys.argv.pop(1)) as config_file:
    CONFIG = json.load(config_file)


class GoodMorningTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.hass = HomeAssistant(self.directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        self.calls = []
        scripts = copy.deepcopy(CONFIG["script"])
        morning = scripts["good_morning"]
        desk = morning["sequence"][-1]["parallel"][1]["sequence"]
        self.assertEqual(desk[0], {"delay": "00:10:00"})
        desk[0] = {"delay": {"milliseconds": 100}}
        self.assertIs(
            await bootstrap.async_from_config_dict(
                {
                    "script": scripts,
                    "scene": CONFIG["scene"],
                    "input_boolean": CONFIG["input_boolean"],
                },
                self.hass,
            ),
            self.hass,
        )
        await self.hass.async_start()
        await self.hass.async_block_till_done()

        async def record_call(call):
            self.calls.append((call.domain, call.service, call.data))

        self.hass.services.async_register("switch", "turn_on", record_call)
        self.hass.services.async_register(
            "shell_command", "hermes_betty_good_morning_dj", record_call
        )

    async def asyncTearDown(self):
        await self.hass.async_stop()

    async def run_morning(self):
        await self.hass.services.async_call("script", "good_morning", blocking=True)
        await self.hass.async_block_till_done()

    async def test_manual_ignores_focus_and_applies_scene_before_desk(self):
        for focus in ("Sleep", "unknown", "unavailable", "Work", "", None):
            with self.subTest(focus=focus):
                if focus is None:
                    self.hass.states.async_remove("sensor.edmunds_iphone_focus_name")
                else:
                    self.hass.states.async_set(
                        "sensor.edmunds_iphone_focus_name", focus
                    )
                await self.hass.services.async_call(
                    "input_boolean",
                    "turn_on",
                    {"entity_id": "input_boolean.goodnight"},
                    blocking=True,
                )
                self.calls.clear()
                task = asyncio.create_task(self.run_morning())
                await asyncio.sleep(0.05)
                self.assertEqual(
                    self.hass.states.get("input_boolean.goodnight").state, "off"
                )
                self.assertFalse(any(domain == "switch" for domain, _, _ in self.calls))
                await task
                self.assertEqual(
                    self.calls,
                    [
                        ("shell_command", "hermes_betty_good_morning_dj", {}),
                        (
                            "switch",
                            "turn_on",
                            {"entity_id": ["switch.desk_monitor", "switch.desk_pop"]},
                        ),
                    ],
                )

    async def test_return_to_goodnight_blocks_pending_desk(self):
        self.hass.states.async_set("sensor.edmunds_iphone_focus_name", "Work")
        task = asyncio.create_task(self.run_morning())
        await asyncio.sleep(0.05)
        self.hass.states.async_set("input_boolean.goodnight", "on")
        await task
        self.assertFalse(any(domain == "switch" for domain, _, _ in self.calls))
        self.assertTrue(any(domain == "shell_command" for domain, _, _ in self.calls))

    async def test_automatic_focus_and_resident_gate_remains_separate(self):
        automatic = next(
            a for a in CONFIG["automation"] if a["id"] == "good_morning_both_awake"
        )
        gate = Template(automatic["condition"][-1]["value_template"], self.hass)
        for entity in ("person.edmund_miller", "person.moni"):
            self.hass.states.async_set(entity, "home")
        for entity in ("input_boolean.edmund_awake", "input_boolean.monica_awake"):
            self.hass.states.async_set(entity, "on")
        for focus, expected in (
            ("Sleep", False),
            ("unknown", False),
            ("unavailable", False),
            ("Work", True),
        ):
            with self.subTest(focus=focus):
                self.hass.states.async_set("sensor.edmunds_iphone_focus_name", focus)
                self.assertIs(gate.async_render(), expected)
        self.hass.states.async_set("input_boolean.monica_awake", "off")
        self.assertIs(gate.async_render(), False)
        self.hass.states.async_set("person.moni", "not_home")
        self.assertIs(gate.async_render(), True)


if __name__ == "__main__":
    unittest.main()
