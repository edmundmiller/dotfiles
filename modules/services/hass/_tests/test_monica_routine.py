"""Exercise Nix-exported NFC config in isolated HA; pass config JSON as argv[1]."""

import copy
import json
import sys
import tempfile
import unittest
from datetime import datetime
from unittest.mock import patch
from zoneinfo import ZoneInfo

from homeassistant import bootstrap, loader
from homeassistant.config_entries import ConfigEntries
from homeassistant.core import HomeAssistant
from homeassistant.setup import async_setup_component
from homeassistant.util import dt as dt_util


with open(sys.argv.pop(1)) as config_file:
    CONFIG = json.load(config_file)

MIRROR = "6eb25d1e-ef99-476e-a496-06181b2ec05e"
NIGHTSTAND = "a394c0fe-467f-4a3d-8060-c1158b74d689"
STARTED = "input_text.monica_routine_started_at"
IN_BED = "input_text.monica_in_bed_at"
DURATION = "sensor.monica_bedtime_routine_duration"
CENTRAL = ZoneInfo("America/Chicago")


class MonicaRoutineTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.config = copy.deepcopy(CONFIG)
        for automation in self.config["automation"]:
            self.assertEqual(automation["action"][-1], {"delay": "00:00:10"})
            automation["action"][-1] = {"delay": {"milliseconds": 200}}
        self.calls = []
        await self.start_hass()

    async def start_hass(self):
        self.hass = HomeAssistant(self.directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        self.hass.config_entries = ConfigEntries(self.hass, self.config)
        await bootstrap.async_load_base_functionality(self.hass)
        await self.hass.config.async_set_time_zone("America/Chicago")
        for domain in (
            "input_text",
            "input_boolean",
            "timer",
            "template",
            "automation",
        ):
            self.assertTrue(await async_setup_component(self.hass, domain, self.config))
        self.hass.states.async_set("script.good_morning", "off")

        async def record_script(call):
            self.calls.append(call.service)

        # Observe requests to existing scripts without loading physical integrations.
        for service in ("goodnight", "get_ready_for_bed"):
            self.hass.services.async_register("script", service, record_script)
        await self.hass.async_start()
        await self.hass.async_block_till_done()

    async def asyncTearDown(self):
        await self.hass.async_stop()

    async def scan(self, tag, when, duplicate=False):
        local_time = datetime.fromisoformat(when).replace(tzinfo=CENTRAL)
        with patch.object(dt_util, "now", return_value=local_time):
            self.hass.bus.async_fire("tag_scanned", {"tag_id": tag})
            if duplicate:
                self.hass.bus.async_fire("tag_scanned", {"tag_id": tag})
            await self.hass.async_block_till_done()

    def state(self, entity):
        return self.hass.states.get(entity).state

    async def test_cross_midnight_duration_then_lights_off_and_duplicates(self):
        await self.scan(MIRROR, "2026-11-02T23:50:00")
        self.assertEqual(self.state(STARTED), "2026-11-02T23:50:00-06:00")
        self.assertEqual(self.state("timer.mirror_bedtime"), "active")
        self.assertEqual(self.calls, ["get_ready_for_bed"])
        await self.scan(MIRROR, "2026-11-02T23:55:00")
        self.assertEqual(self.state(STARTED), "2026-11-02T23:50:00-06:00")
        # Reminder expiry must not stop elapsed-time tracking.
        await self.hass.services.async_call(
            "timer", "finish", {"entity_id": "timer.mirror_bedtime"}, blocking=True
        )
        await self.scan(NIGHTSTAND, "2026-11-03T00:17:30", duplicate=True)
        self.assertEqual(float(self.state(DURATION)), 27.5)
        self.assertEqual(self.state(IN_BED), "2026-11-03T00:17:30-06:00")
        self.assertEqual(self.calls, ["get_ready_for_bed"])
        await self.scan(NIGHTSTAND, "2026-11-03T00:18:00")
        self.assertEqual(self.calls, ["get_ready_for_bed", "goodnight"])
        await self.scan(MIRROR, "2026-11-03T00:19:00")
        self.assertEqual(float(self.state(DURATION)), 27.5)
        self.assertEqual(self.state(IN_BED), "2026-11-03T00:17:30-06:00")
        self.assertEqual(self.state(STARTED), "2026-11-02T23:50:00-06:00")

    async def test_existing_bedtime_mode_restart_and_equal_next_night_duration(self):
        await self.hass.services.async_call(
            "input_boolean",
            "turn_on",
            {"entity_id": "input_boolean.goodnight"},
            blocking=True,
        )
        await self.scan(MIRROR, "2026-11-02T22:00:00")
        self.assertEqual(self.calls, [])
        await self.hass.async_stop()
        await self.start_hass()
        self.assertEqual(self.state(STARTED), "2026-11-02T22:00:00-06:00")
        await self.scan(NIGHTSTAND, "2026-11-02T22:07:15")
        self.assertEqual(float(self.state(DURATION)), 7.25)
        self.assertEqual(self.state("timer.mirror_bedtime"), "idle")
        self.assertEqual(self.calls, [])
        first_record = [{"start": 1793678400, "end": 1793678835}]
        self.assertEqual(
            self.hass.states.get(DURATION).attributes["nightly_records"], first_record
        )
        await self.hass.async_stop()
        await self.start_hass()
        self.assertEqual(float(self.state(DURATION)), 7.25)
        self.assertEqual(
            self.hass.states.get(DURATION).attributes["nightly_records"], first_record
        )
        await self.scan(NIGHTSTAND, "2026-11-02T22:08:00")
        self.assertEqual(self.calls, ["goodnight"])
        await self.scan(MIRROR, "2026-11-03T22:00:00")
        await self.scan(NIGHTSTAND, "2026-11-03T22:07:15")
        self.assertEqual(float(self.state(DURATION)), 7.25)
        self.assertEqual(
            self.hass.states.get(DURATION).attributes["completed_at"],
            "2026-11-03T22:07:15-06:00",
        )
        self.assertEqual(
            self.hass.states.get(DURATION).attributes["nightly_records"],
            first_record + [{"start": 1793764800, "end": 1793765235}],
        )

    async def test_yearly_records_keep_cutoff_and_drop_older_completion(self):
        for date in ("2025-11-02", "2025-11-03", "2025-11-04", "2026-11-03"):
            await self.scan(MIRROR, f"{date}T22:00:00")
            await self.scan(NIGHTSTAND, f"{date}T22:07:15")
        records = self.hass.states.get(DURATION).attributes["nightly_records"]
        self.assertEqual(
            [datetime.fromtimestamp(r["end"], CENTRAL).isoformat() for r in records],
            [
                "2025-11-03T22:07:15-06:00",
                "2025-11-04T22:07:15-06:00",
                "2026-11-03T22:07:15-06:00",
            ],
        )
        self.assertEqual([r["end"] - r["start"] for r in records], [435, 435, 435])

    async def test_missing_mirror_stale_start_and_daytime_are_not_measurements(self):
        await self.scan(MIRROR, "2026-11-02T19:59:59")
        await self.scan(NIGHTSTAND, "2026-11-02T19:59:59")
        self.assertEqual(self.state(STARTED), "unknown")
        self.assertEqual(self.state(IN_BED), "unknown")
        await self.scan(NIGHTSTAND, "2026-11-02T20:00:00")
        self.assertEqual(self.state(DURATION), "unknown")
        self.assertEqual(self.calls, [])
        await self.scan(NIGHTSTAND, "2026-11-02T20:01:00")
        self.assertEqual(self.calls, ["goodnight"])
        self.calls.clear()
        await self.scan(MIRROR, "2026-11-03T20:00:00")
        await self.scan(NIGHTSTAND, "2026-11-04T04:00:00")
        self.assertEqual(self.state(IN_BED), "2026-11-02T20:00:00-06:00")
        await self.scan(NIGHTSTAND, "2026-11-04T22:00:00")
        self.assertEqual(self.state(DURATION), "unknown")
        self.assertEqual(self.calls, ["get_ready_for_bed"])
        self.hass.states.async_set("script.good_morning", "on")
        await self.scan(MIRROR, "2026-11-05T22:00:00")
        await self.scan(NIGHTSTAND, "2026-11-05T22:00:00")
        self.assertEqual(self.state(STARTED), "2026-11-03T20:00:00-06:00")
        self.assertEqual(self.state(IN_BED), "2026-11-04T22:00:00-06:00")


if __name__ == "__main__":
    unittest.main()
