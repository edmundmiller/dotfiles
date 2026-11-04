"""Run the Nix-exported entrance automation actions in isolated Home Assistant.

Pass the automation JSON as argv[1], using Python with Home Assistant installed.
Only durations are accelerated; no network integrations or devices are loaded.
"""

import asyncio
import copy
import json
import sys
import tempfile
import unittest

from homeassistant import loader
from homeassistant.core import Context, HomeAssistant
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.script import Script, async_validate_actions_config


with open(sys.argv.pop(1)) as automation_file:
    AUTOMATION = json.load(automation_file)

LIGHT = "light.smart_night_light_w"
OCCUPANCY = "binary_sensor.smart_night_light_w_occupancy"


class EntranceNightLightTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.hass = HomeAssistant(directory.name)
        loader.async_setup(self.hass)
        self.hass.states.async_set(LIGHT, "on")
        self.hass.states.async_set(OCCUPANCY, "off")
        self.calls = []
        self.failures_remaining = 0
        self.motion_after_failure = None

        async def turn_off(call):
            self.calls.append(call.data)
            if self.failures_remaining:
                self.failures_remaining -= 1
                if self.motion_after_failure is not None:
                    self.hass.states.async_set(OCCUPANCY, self.motion_after_failure)
                raise HomeAssistantError("Matter command timed out")
            self.hass.states.async_set(LIGHT, "off")

        self.hass.services.async_register("light", "turn_off", turn_off)
        actions = copy.deepcopy(AUTOMATION["action"])
        self.assertEqual(actions[0]["delay"], {"minutes": 2})
        actions[0]["delay"] = {"milliseconds": 80}
        for action in actions:
            if action.get("condition") == "state" and action.get("entity_id") == OCCUPANCY:
                self.assertEqual(action["for"], {"minutes": 2})
                action["for"] = {"milliseconds": 60}
            if "wait_template" in action:
                self.assertEqual(action["timeout"], {"seconds": 10})
                action["timeout"] = {"milliseconds": 120}
        sequence = await async_validate_actions_config(self.hass, cv.SCRIPT_SCHEMA(actions))
        self.script = Script(
            self.hass, sequence, "entrance_retry", "automation",
            script_mode=AUTOMATION["mode"],
        )

    async def asyncTearDown(self):
        await self.script.async_stop()
        await self.hass.async_stop()

    async def test_timeout_retries_once_and_turns_light_off(self):
        self.failures_remaining = 1
        await self.script.async_run(context=Context())
        self.assertEqual(self.calls, [{"entity_id": [LIGHT]}, {"entity_id": [LIGHT]}])
        self.assertEqual(self.hass.states.get(LIGHT).state, "off")

    async def test_persistent_failure_stops_after_two_attempts_and_remains_an_error(self):
        self.failures_remaining = 10
        with self.assertRaisesRegex(HomeAssistantError, "Matter command timed out"):
            await self.script.async_run(context=Context())
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(self.hass.states.get(LIGHT).state, "on")

    async def test_success_needs_no_retry(self):
        await self.script.async_run(context=Context())
        self.assertEqual(self.calls, [{"entity_id": [LIGHT]}])
        self.assertEqual(self.hass.states.get(LIGHT).state, "off")

    async def test_motion_or_unavailable_occupancy_prevents_retry(self):
        for state in ("on", "unavailable"):
            with self.subTest(state=state):
                self.hass.states.async_set(OCCUPANCY, "off")
                self.calls.clear()
                self.failures_remaining = 1
                self.motion_after_failure = state
                await self.script.async_run(context=Context())
                self.assertEqual(len(self.calls), 1)
                self.assertEqual(self.hass.states.get(LIGHT).state, "on")

    async def test_recently_cleared_motion_prevents_retry(self):
        self.failures_remaining = 1
        self.motion_after_failure = "on"
        task = asyncio.create_task(self.script.async_run(context=Context()))
        try:
            async with asyncio.timeout(2):
                while not self.calls:
                    await asyncio.sleep(0.01)
            await asyncio.sleep(0.09)
            self.hass.states.async_set(OCCUPANCY, "off")
            await task
        finally:
            if not task.done():
                task.cancel()
                await asyncio.gather(task, return_exceptions=True)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.hass.states.get(LIGHT).state, "on")


if __name__ == "__main__":
    unittest.main()
