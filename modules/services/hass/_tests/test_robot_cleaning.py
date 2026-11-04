"""Run the exported cleaning policy in isolated HA, without physical devices."""

import copy
import json
import os
import sys
import tempfile
import time
import unittest
from datetime import datetime
from importlib.resources import files
from unittest.mock import patch
from zoneinfo import ZoneInfo

from homeassistant import bootstrap, loader
from homeassistant.config_entries import ConfigEntries
from homeassistant.core import HomeAssistant
from homeassistant.setup import async_setup_component
from homeassistant.util import dt as dt_util


with open(sys.argv.pop(1)) as config_file:
    CONFIG = json.load(config_file)

# Match the NUC host timezone used to parse HA's offset-free helper states.
os.environ["TZDIR"] = str(files("tzdata").joinpath("zoneinfo"))
os.environ["TZ"] = "America/Chicago"
time.tzset()


class RobotCleaningTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        await self.start_hass()

    async def start_hass(self):
        self.hass = HomeAssistant(self.directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        config = copy.deepcopy(CONFIG)
        wait = config["script"]["robot_cleaning_refresh_presence"]["sequence"][-1]
        self.assertEqual(wait["timeout"], "00:00:30")
        wait["timeout"] = {"milliseconds": 100}
        self.hass.config_entries = ConfigEntries(self.hass, config)
        self.assertTrue(await bootstrap.async_load_base_functionality(self.hass))
        await self.hass.config.async_set_time_zone("America/Chicago")
        for domain in (
            "input_boolean",
            "input_datetime",
            "input_text",
            "script",
            "automation",
        ):
            self.assertTrue(await async_setup_component(self.hass, domain, config))
        await self.hass.async_start()
        await self.hass.async_block_till_done()
        self.calls = []

        async def record(call):
            self.calls.append((call.domain, call.service, dict(call.data)))

        for domain, service in (
            ("notify", "mobile_app_edmunds_iphone"),
            ("notify", "mobile_app_monicas_iphone"),
            ("vacuum", "send_command"),
            ("vacuum", "return_to_base"),
        ):
            self.hass.services.async_register(domain, service, record)
        self.hass.states.async_set("input_boolean.robot_cleaning_enabled", "on")
        for entity in ("vacation_mode", "guest_mode", "goodnight"):
            self.hass.states.async_set(f"input_boolean.{entity}", "off")
        departed = datetime(2026, 11, 4, 9, tzinfo=ZoneInfo("America/Chicago"))
        with patch.object(
            dt_util, "utcnow", return_value=departed.astimezone(dt_util.UTC)
        ):
            for phone in ("edmunds", "monicas"):
                self.hass.states.async_set(f"device_tracker.{phone}_iphone", "not_home")
        await self.hass.async_block_till_done()
        for name in CONFIG["input_datetime"]:
            self.hass.states.async_set(f"input_datetime.{name}", "2026-07-23 00:00:00")

    async def asyncTearDown(self):
        await self.hass.async_stop()

    async def monitor(self, day=4):
        when = datetime(2026, 11, day, 12, 2, tzinfo=ZoneInfo("America/Chicago"))
        with patch.object(dt_util, "now", return_value=when):
            await self.hass.services.async_call(
                "automation",
                "trigger",
                {
                    "entity_id": "automation.robot_cleaning_exception_monitor",
                    "skip_condition": False,
                },
                blocking=True,
            )
            await self.hass.async_block_till_done()

    def alerts(self):
        return [
            data
            for domain, _, data in self.calls
            if domain == "notify" and data["message"] != "request_location_update"
        ]

    def configure_maps(self):
        for name in CONFIG["input_text"]:
            if name.endswith(("pmap_id", "pmapv_id", "region_ids")):
                self.hass.states.async_set(f"input_text.{name}", "1")

    async def test_missing_maps_report_once_instead_of_daily_phone_blame(self):
        await self.monitor()
        self.assertEqual(len(self.alerts()), 1)
        self.assertIn("saved-map", self.alerts()[0]["message"].lower())
        self.assertFalse(
            any(
                data.get("message") == "request_location_update"
                for _, _, data in self.calls
            )
        )
        await self.monitor(day=5)
        self.assertEqual(len(self.alerts()), 1)
        self.assertFalse(any(domain == "vacuum" for domain, _, _ in self.calls))
        await self.hass.async_stop()
        await self.start_hass()
        await self.monitor(day=6)
        self.assertEqual(self.alerts(), [])

    async def test_phone_timeout_retries_but_does_not_repeat_alert(self):
        self.configure_maps()

        async def edmund_replies(call):
            self.calls.append((call.domain, call.service, dict(call.data)))
            if call.data["message"] == "request_location_update":
                self.hass.states.async_set(
                    "device_tracker.edmunds_iphone",
                    "not_home",
                    {"latitude": len(self.calls)},
                )

        self.hass.services.async_register(
            "notify", "mobile_app_edmunds_iphone", edmund_replies
        )
        await self.monitor()
        await self.monitor(day=5)
        self.assertEqual(len(self.alerts()), 1)
        self.assertNotIn("Edmund", self.alerts()[0]["message"])
        self.assertIn("Monica", self.alerts()[0]["message"])
        self.assertEqual(
            sum(
                data.get("message") == "request_location_update"
                for _, _, data in self.calls
            ),
            4,
        )
        self.assertFalse(any(domain == "vacuum" for domain, _, _ in self.calls))

    async def test_changed_blocker_is_reported_without_claiming_recovery(self):
        await self.monitor()
        self.configure_maps()
        await self.monitor(day=5)
        self.assertEqual(len(self.alerts()), 2)
        self.assertIn("location", self.alerts()[1]["message"])
        self.assertNotIn("completed", self.alerts()[1]["title"])

    async def test_success_clears_incident_and_reports_outcome_once(self):
        self.configure_maps()
        await self.monitor()
        self.calls.clear()
        self.hass.states.async_set("vacuum.rosie", "docked", {"bin_present": True})
        self.hass.states.async_set("binary_sensor.rosie_bin_full", "off")
        self.hass.states.async_set("sensor.rosie_battery", "100")
        for kind, value in (("successful", "10"), ("failed", "2"), ("canceled", "3")):
            self.hass.states.async_set(f"sensor.rosie_{kind}_missions", value)

        async def finish_mission(call):
            count = int(self.hass.states.get("sensor.rosie_successful_missions").state)
            self.hass.states.async_set(
                "sensor.rosie_successful_missions", str(count + 1)
            )

        self.hass.services.async_register("vacuum", "send_command", finish_mission)
        for _ in range(2):
            await self.hass.services.async_call(
                "script",
                "robot_cleaning_run_job",
                {"job": "rosie_high_traffic", "manual_test": True},
                blocking=True,
            )
            await self.hass.async_block_till_done()
        self.assertEqual(len(self.alerts()), 1)
        self.assertEqual(self.alerts()[0]["title"], "Robot cleaning completed")
        self.assertEqual(
            self.hass.states.get("input_text.robot_cleaning_last_exception").state, ""
        )
        self.assertNotEqual(
            self.hass.states.get(
                "input_datetime.robot_cleaning_rosie_high_traffic_last_success"
            ).state,
            "2026-07-23 00:00:00",
        )

    async def test_stale_presence_cannot_dispatch_even_with_maps(self):
        self.configure_maps()
        when = datetime(2026, 11, 4, 12, 2, tzinfo=ZoneInfo("America/Chicago"))
        with patch.object(dt_util, "now", return_value=when):
            await self.hass.services.async_call(
                "script", "robot_cleaning_dispatch", blocking=True
            )
            self.hass.states.async_set(
                "input_datetime.robot_cleaning_last_dispatch", "2026-11-04 12:00:00"
            )
            await self.hass.services.async_call(
                "script",
                "robot_cleaning_run_job",
                {"job": "rosie_high_traffic", "from_dispatch": True},
                blocking=True,
            )
        self.assertEqual(self.calls, [])

    async def test_vacation_is_quiet(self):
        self.hass.states.async_set("input_boolean.vacation_mode", "on")
        await self.monitor()
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
