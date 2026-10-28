"""Exercise NFC scans in isolated HA using pets.nix config exported as argv[1]."""

import json
import sys
import tempfile
import unittest
from datetime import datetime
from unittest.mock import patch
from zoneinfo import ZoneInfo

from homeassistant import bootstrap, loader
from homeassistant.config_entries import ConfigEntries, ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import device_registry
from homeassistant.setup import async_setup_component
from homeassistant.util import dt as dt_util


with open(sys.argv.pop(1)) as config_file:
    CONFIG = json.load(config_file)

TAG = "32eb4a84-1dbb-477a-a775-6a344c3a7b25"
LAST_TREAT = "input_text.phoebe_last_dental_treat"
CENTRAL = ZoneInfo("America/Chicago")


class DentalTreatTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.hass = HomeAssistant(self.directory.name)
        self.hass.config.skip_pip = True
        loader.async_setup(self.hass)
        self.hass.config_entries = ConfigEntries(self.hass, CONFIG)
        self.assertTrue(await bootstrap.async_load_base_functionality(self.hass))
        await self.hass.config.async_set_time_zone("America/Chicago")
        for domain in ("input_datetime", "input_text", "automation"):
            self.assertTrue(await async_setup_component(self.hass, domain, CONFIG))
        await self.hass.async_start()
        await self.hass.async_block_till_done()
        self.calls = []

        async def record(call):
            self.calls.append((call.domain, call.service, dict(call.data)))

        for domain, service in (
            ("logbook", "log"),
            ("notify", "mobile_app_first_phone"),
            ("notify", "mobile_app_second_phone"),
            ("notify", "notify"),
        ):
            self.hass.services.async_register(domain, service, record)

        entry = ConfigEntry(
            domain="mobile_app",
            title="Phones",
            data={},
            options={},
            source="user",
            unique_id=None,
            version=1,
            minor_version=1,
            discovery_keys={},
            subentries_data=[],
        )
        # Register device identity without loading mobile app network integrations.
        with patch.object(self.hass.config_entries, "async_setup", return_value=True):
            await self.hass.config_entries.async_add(entry)
        registry = device_registry.async_get(self.hass)
        self.phones = [
            registry.async_get_or_create(
                config_entry_id=entry.entry_id,
                identifiers={("mobile_app", name)},
                name=name,
            ).id
            for name in ("First Phone", "Second Phone")
        ]
        registry.async_update_device(self.phones[1], name_by_user="Renamed phone")

    async def asyncTearDown(self):
        await self.hass.async_stop()

    async def scan(self, when, phone=0, tag=TAG):
        local_time = datetime.fromisoformat(when).replace(tzinfo=CENTRAL)
        with patch.object(dt_util, "now", return_value=local_time):
            self.hass.bus.async_fire(
                "tag_scanned", {"tag_id": tag, "device_id": self.phones[phone]}
            )
            await self.hass.async_block_till_done()

    async def test_first_scan_logs_once_and_duplicates_notify_only_scanner(self):
        await self.scan("2026-10-27T22:00:00", tag="unrelated-tag")
        self.assertEqual(self.calls, [])
        await self.scan("2026-10-27T22:00:00")
        self.assertEqual(
            self.calls,
            [
                (
                    "logbook",
                    "log",
                    {
                        "name": "Phoebe Dental Treat",
                        "message": "Phoebe was given 1 small Yummy Combs dental treat, 49 kcal.",
                        "entity_id": LAST_TREAT,
                    },
                )
            ],
        )
        first_time = self.hass.states.get(LAST_TREAT).state
        self.calls.clear()
        await self.scan("2026-10-27T23:00:00", phone=1)
        await self.scan("2026-10-28T00:15:00")
        self.assertEqual(
            [(domain, service) for domain, service, _ in self.calls],
            [
                ("notify", "mobile_app_second_phone"),
                ("notify", "mobile_app_first_phone"),
            ],
        )
        self.assertTrue(
            all(
                "already got her dental treat" in data["message"]
                for _, _, data in self.calls
            )
        )
        self.assertEqual(self.hass.states.get(LAST_TREAT).state, first_time)

    async def test_six_am_boundary_including_dst_changes(self):
        for evening, morning in (
            ("2026-10-27", "2026-10-28"),
            ("2026-03-07", "2026-03-08"),
            ("2026-10-31", "2026-11-01"),
        ):
            with self.subTest(morning=morning):
                last_treat = datetime.fromisoformat(f"{evening}T22:00:00").replace(
                    tzinfo=CENTRAL
                )
                await self.hass.services.async_call(
                    "input_text",
                    "set_value",
                    {"entity_id": LAST_TREAT, "value": last_treat.isoformat()},
                    blocking=True,
                )
                self.calls.clear()
                await self.scan(f"{morning}T05:59:59")
                self.assertEqual(
                    self.calls[0][:2], ("notify", "mobile_app_first_phone")
                )
                self.calls.clear()
                await self.scan(f"{morning}T06:00:00")
                self.assertEqual(len(self.calls), 1)
                self.assertEqual(self.calls[0][:2], ("logbook", "log"))

    async def test_simultaneous_scans_log_one_treat_and_warn_second_phone(self):
        when = datetime(2026, 10, 27, 22, tzinfo=CENTRAL)
        with patch.object(dt_util, "now", return_value=when):
            for phone in self.phones:
                self.hass.bus.async_fire(
                    "tag_scanned", {"tag_id": TAG, "device_id": phone}
                )
            await self.hass.async_block_till_done()
        self.assertEqual(
            [(domain, service) for domain, service, _ in self.calls],
            [("logbook", "log"), ("notify", "mobile_app_second_phone")],
        )

    async def test_unknown_scanner_never_broadcasts_or_logs_again(self):
        await self.scan("2026-10-27T22:00:00")
        self.calls.clear()
        self.phones.append("unknown-device")
        await self.scan("2026-10-27T23:00:00", phone=2)
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
