"""Exercise the Nix-exported automation in an isolated Home Assistant runtime.

Pass the exported automation JSON as argv[1]; requires Home Assistant installed.
Only the timer duration is accelerated, after asserting the five-minute contract.
No network integrations or physical devices are loaded.
"""

import asyncio
import copy
import json
import sys
import tempfile
import unittest

from homeassistant import bootstrap, loader
from homeassistant.core import HomeAssistant


with open(sys.argv.pop(1)) as automation_file:
    AUTOMATION = json.load(automation_file)


class BedtimeAudioTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.hass = HomeAssistant(self.directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        self.calls = []

        async def turn_on(call):
            self.calls.append(call.data)

        for entity, state in {
            "input_boolean.goodnight": "off",
            "input_boolean.sleep_done": "off",
            "switch.eve_energy_20ebu4101": "off",
            "media_player.bathroom_nightstand_2": "idle",
            "media_player.window_nightstand_2": "idle",
        }.items():
            self.hass.states.async_set(entity, state)

        automation = copy.deepcopy(AUTOMATION)
        self.assertEqual(automation["trigger"][0]["for"], {"minutes": 5})
        automation["trigger"][0]["for"] = {"seconds": 1}
        self.assertIs(
            await bootstrap.async_from_config_dict(
                {"automation": [automation]}, self.hass
            ),
            self.hass,
        )
        await self.hass.async_start()
        await self.hass.async_block_till_done()
        self.hass.services.async_register("switch", "turn_on", turn_on)
        self.assertEqual(len(self.hass.states.async_all("automation")), 1)

    async def asyncTearDown(self):
        await self.hass.async_stop()

    async def set_state(self, entity, state, attributes=None):
        self.hass.states.async_set(entity, state, attributes)
        await self.hass.async_block_till_done()

    async def wait_timer(self):
        await asyncio.sleep(1.2)
        await self.hass.async_block_till_done()

    async def test_either_speaker_without_sleep_or_heart_rate(self):
        await self.set_state("input_boolean.goodnight", "on")
        for speaker in ("bathroom_nightstand_2", "window_nightstand_2"):
            await self.set_state(f"media_player.{speaker}", "playing")
            await asyncio.sleep(0.3)
            self.assertEqual(self.calls, [])
            # Chapter metadata must not restart the continuous playback timer.
            await self.set_state(
                f"media_player.{speaker}", "playing", {"media_title": "012"}
            )
            await asyncio.sleep(0.9)
            await self.hass.async_block_till_done()
            self.assertEqual(
                self.calls, [{"entity_id": ["switch.eve_energy_20ebu4101"]}]
            )
            self.calls.clear()
            await self.set_state(f"media_player.{speaker}", "paused")

    async def test_pause_resets_timer_and_good_morning_cancels(self):
        await self.set_state("input_boolean.goodnight", "on")
        await self.set_state("media_player.bathroom_nightstand_2", "playing")
        await asyncio.sleep(0.6)
        await self.set_state("media_player.bathroom_nightstand_2", "paused")
        await self.set_state("media_player.bathroom_nightstand_2", "playing")
        await asyncio.sleep(0.6)
        self.assertEqual(self.calls, [])
        await self.set_state("input_boolean.goodnight", "off")
        await self.wait_timer()
        self.assertEqual(self.calls, [])

    async def test_daytime_and_unrelated_audio_do_not_start_noise(self):
        await self.set_state("media_player.window_nightstand_2", "playing")
        await self.wait_timer()
        self.assertEqual(self.calls, [])
        await self.set_state("media_player.window_nightstand_2", "idle")
        await self.set_state("input_boolean.goodnight", "on")
        await self.set_state("media_player.bathroom", "playing")
        await self.set_state("media_player.window_nightstand", "playing")
        await self.wait_timer()
        self.assertEqual(self.calls, [])

    async def test_bedtime_after_playback_starts_and_already_on_outlet(self):
        await self.set_state("media_player.window_nightstand_2", "playing")
        await self.set_state("switch.eve_energy_20ebu4101", "on")
        await self.set_state("input_boolean.goodnight", "on")
        await self.wait_timer()
        self.assertEqual(self.calls, [])
        # Turning off the outlet during ongoing audio must not retrigger it.
        await self.set_state("switch.eve_energy_20ebu4101", "off")
        await self.wait_timer()
        self.assertEqual(self.calls, [])
        await self.set_state("input_boolean.goodnight", "off")
        await self.set_state("input_boolean.goodnight", "on")
        await self.wait_timer()
        self.assertEqual(self.calls, [{"entity_id": ["switch.eve_energy_20ebu4101"]}])


if __name__ == "__main__":
    unittest.main()
