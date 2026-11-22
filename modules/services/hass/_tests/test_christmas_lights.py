"""Exercise seasonal lighting in isolated HA; pass Nix-exported config as argv[1]."""

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

PLUGS = (
    "switch.living_room_christmas_tree",
    "switch.white_icicles",
    "switch.christmas_tree_forest",
)
CENTRAL = ZoneInfo("America/Chicago")


class ChristmasLightsTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.hass = HomeAssistant(directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        self.hass.config_entries = ConfigEntries(self.hass, CONFIG)
        await bootstrap.async_load_base_functionality(self.hass)
        await self.hass.config.async_set_time_zone("America/Chicago")
        self.hass.config.latitude = 30.27
        self.hass.config.longitude = -97.74
        self.fail_plugs = False

        async def switch(call):
            if self.fail_plugs:
                raise RuntimeError("Disconnected seasonal plug")
            for entity in call.data["entity_id"]:
                self.hass.states.async_set(entity, "on" if call.service == "turn_on" else "off")

        async def lights_off(call):
            for entity in call.data["entity_id"]:
                self.hass.states.async_set(entity, "off")

        async def close_cover(call):
            self.hass.states.async_set("cover.smartwings_window_covering", "closed")

        async def tv_off(call):
            self.hass.states.async_set("media_player.living_room", "off")

        for service in ("turn_on", "turn_off"):
            self.hass.services.async_register("switch", service, switch)
        self.hass.services.async_register("light", "turn_off", lights_off)
        self.hass.services.async_register("cover", "close_cover", close_cover)
        self.hass.services.async_register("script", "tv_off_if_on", tv_off)
        self.reset_states()
        for domain in ("script", "automation"):
            self.assertTrue(await async_setup_component(self.hass, domain, CONFIG))
        await self.hass.async_start()
        await self.hass.async_block_till_done()

    def reset_states(self):
        for entity, state in {
            "person.edmund_miller": "home",
            "person.moni": "not_home",
            "sensor.edmunds_iphone_ssid": "unavailable",
            "sensor.monicas_iphone_ssid": "unavailable",
            "input_boolean.goodnight": "off",
            "input_boolean.vacation_mode": "off",
        }.items():
            self.hass.states.async_set(entity, state)

    async def asyncTearDown(self):
        await self.hass.async_stop()

    async def reconcile(self, date, expected):
        now = datetime.fromisoformat(date).replace(tzinfo=CENTRAL)
        # Start with the opposite state so either branch must actually act.
        for plug in PLUGS:
            self.hass.states.async_set(plug, "off" if expected == "on" else "on")
        await self.hass.async_block_till_done()
        with patch.object(dt_util, "now", return_value=now), patch.object(
            dt_util, "utcnow", return_value=now.astimezone(dt_util.UTC)
        ):
            await self.hass.services.async_call(
                "automation", "trigger", {"entity_id": "automation.christmas_lights"}, blocking=True
            )
            await self.hass.async_block_till_done()
        self.assertEqual([self.hass.states.get(plug).state for plug in PLUGS], [expected] * 3)

    async def test_season_and_nightly_boundaries(self):
        for date, expected in (
            ("2026-11-14T19:00:00", "off"),
            ("2026-11-15T19:00:00", "on"),
            ("2026-12-25T12:00:00", "off"),
            ("2026-12-25T17:00:00", "off"),
            ("2026-12-25T17:15:00", "on"),
            ("2026-12-25T22:59:59", "on"),
            ("2026-12-25T23:00:00", "off"),
            ("2027-01-06T19:00:00", "on"),
            ("2027-01-07T19:00:00", "off"),
            ("2026-07-04T21:00:00", "off"),
            ("2026-12-25T00:15:00", "off"),
        ):
            with self.subTest(date=date):
                await self.reconcile(date, expected)

    async def test_bedtime_vacation_and_absence_override_evening(self):
        for entity in ("input_boolean.goodnight", "input_boolean.vacation_mode", "person.edmund_miller"):
            with self.subTest(entity=entity):
                self.reset_states()
                self.hass.states.async_set(entity, "not_home" if entity.startswith("person.") else "on")
                await self.reconcile("2026-12-24T19:00:00", "off")

    async def test_either_person_or_home_wifi_is_enough(self):
        for entity, state in (
            ("person.moni", "home"),
            ("sensor.edmunds_iphone_ssid", "Aviato"),
            ("sensor.monicas_iphone_ssid", "Aviato"),
        ):
            with self.subTest(entity=entity):
                self.reset_states()
                self.hass.states.async_set("person.edmund_miller", "not_home")
                self.hass.states.async_set(entity, state)
                await self.reconcile("2026-12-24T19:00:00", "on")

    async def test_presence_bedtime_and_reconnect_events(self):
        now = datetime(2026, 12, 24, 19, tzinfo=CENTRAL)
        with patch.object(dt_util, "now", return_value=now), patch.object(
            dt_util, "utcnow", return_value=now.astimezone(dt_util.UTC)
        ):
            for entity, state, expected in (
                ("person.edmund_miller", "not_home", "off"),
                ("person.moni", "home", "on"),
                ("input_boolean.goodnight", "on", "off"),
                ("input_boolean.goodnight", "off", "on"),
                ("input_boolean.vacation_mode", "on", "off"),
                ("input_boolean.vacation_mode", "off", "on"),
                (PLUGS[0], "unavailable", None),
                (PLUGS[0], "off", "on"),
            ):
                self.hass.states.async_set(entity, state)
                await self.hass.async_block_till_done()
                if expected is not None:
                    self.assertEqual([self.hass.states.get(plug).state for plug in PLUGS], [expected] * 3)
            # Manual off and phone attribute updates must not immediately relight decorations.
            for plug in PLUGS:
                self.hass.states.async_set(plug, "off")
            self.hass.states.async_set("person.moni", "home", {"battery_level": 90})
            await self.hass.async_block_till_done()
            self.assertEqual([self.hass.states.get(plug).state for plug in PLUGS], ["off"] * 3)

    async def test_everything_off_and_disconnected_plug(self):
        for fail in (False, True):
            with self.subTest(disconnected=fail):
                self.fail_plugs = fail
                for entity in (*PLUGS, "light.living_room_couch_lamp", "media_player.living_room"):
                    self.hass.states.async_set(entity, "on")
                self.hass.states.async_set("cover.smartwings_window_covering", "open")
                await self.hass.services.async_call("script", "everything_off", blocking=True)
                if not fail:
                    self.assertEqual([self.hass.states.get(plug).state for plug in PLUGS], ["off"] * 3)
                self.assertEqual(self.hass.states.get("light.living_room_couch_lamp").state, "off")
                self.assertEqual(self.hass.states.get("media_player.living_room").state, "off")
                self.assertEqual(self.hass.states.get("cover.smartwings_window_covering").state, "closed")


if __name__ == "__main__":
    unittest.main()
