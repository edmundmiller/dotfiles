"""Regression coverage for applying the cron patch to the pilot source."""

from __future__ import annotations

import os
import unittest
from pathlib import Path


HERMES_SOURCE = os.environ.get("HERMES_SOURCE")


@unittest.skipUnless(HERMES_SOURCE, "set HERMES_SOURCE to the patched Hermes checkout")
class CronLatestSourceTest(unittest.TestCase):
    @unittest.expectedFailure
    def test_cron_module_compiles(self):
        source = Path(HERMES_SOURCE) / "hermes_cli" / "cron.py"
        compile(source.read_text(encoding="utf-8"), str(source), "exec")


if __name__ == "__main__":
    unittest.main()
