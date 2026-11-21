"""Render the shipped dashboard's pickup card with Home Assistant templates."""

import sys
import tempfile
import unittest
from datetime import datetime
from unittest.mock import patch

import yaml

from homeassistant.core import HomeAssistant
from homeassistant.helpers.template import Template
from homeassistant.util import dt as dt_util


with open(sys.argv.pop(1)) as dashboard_file:
    DASHBOARD = yaml.safe_load(dashboard_file)


class DashboardTest(unittest.IsolatedAsyncioTestCase):
    async def test_valet_pickup_week_and_local_midnight(self):
        with tempfile.TemporaryDirectory() as directory:
            hass = HomeAssistant(directory)
            await hass.config.async_set_time_zone("America/Chicago")
            home = next(view for view in DASHBOARD["views"] if view["path"] == "home")
            card = next(
                card
                for section in home["sections"]
                for card in section["cards"]
                if card.get("title") == "Trash pickup"
            )
            template = Template(card["content"], hass)
            # UTC dates deliberately differ from local dates near the weekend.
            cases = [
                ("2026-11-16T02:00:00+00:00", "Today · Nov 15", False),
                ("2026-11-16T18:00:00+00:00", "Today · Nov 16", False),
                ("2026-11-17T18:00:00+00:00", "Today · Nov 17", False),
                ("2026-11-18T18:00:00+00:00", "Today · Nov 18", False),
                ("2026-11-20T05:59:59+00:00", "Today · Nov 19", False),
                ("2026-11-20T06:00:00+00:00", "Sunday · Nov 22", True),
                ("2026-11-21T05:59:59+00:00", "Sunday · Nov 22", True),
                ("2026-11-21T06:00:00+00:00", "Tomorrow · Nov 22", True),
                ("2026-11-22T05:59:59+00:00", "Tomorrow · Nov 22", True),
                ("2026-11-22T06:00:00+00:00", "Today · Nov 22", False),
                ("2027-01-02T18:00:00+00:00", "Tomorrow · Jan 3", True),
            ]
            for timestamp, heading, self_dispose in cases:
                with self.subTest(timestamp=timestamp), patch.object(
                    dt_util,
                    "now",
                    return_value=dt_util.as_local(datetime.fromisoformat(timestamp)),
                ):
                    rendered = template.async_render()
                    self.assertIn("## " + heading, rendered)
                    self.assertEqual("No valet pickup today" in rendered, self_dispose)
                    self.assertIn("Valet pickup Sunday–Thursday", rendered)
            info = template.async_render_to_info()
            self.assertTrue(info.has_time, "Card must refresh as local time changes")
            self.assertFalse(info.entities, "Pickup card must not depend on entities")


if __name__ == "__main__":
    unittest.main()
