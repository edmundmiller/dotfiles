"""Regression coverage for timer-driven Hermes cron health reporting."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch


HERMES_SOURCE = os.environ.get("HERMES_SOURCE")


def _load_cron_module(source: Path):
    hermes_cli = types.ModuleType("hermes_cli")
    hermes_cli.__path__ = []
    colors = types.ModuleType("hermes_cli.colors")
    colors.Colors = types.SimpleNamespace(
        BLUE="",
        CYAN="",
        DIM="",
        GREEN="",
        RED="",
        YELLOW="",
    )
    colors.color = lambda text, *_args: text

    cron_package = types.ModuleType("cron")
    cron_package.__path__ = []
    lifecycle_guard = types.ModuleType("cron.lifecycle_guard")
    lifecycle_guard.contains_gateway_lifecycle_command = lambda _text: False
    jobs = types.ModuleType("cron.jobs")
    jobs.list_jobs = lambda include_disabled=False: [
        {
            "id": "job-1",
            "name": "Timer job",
            "schedule_display": "every day",
            "state": "scheduled",
            "enabled": True,
            "next_run_at": "2026-07-17T16:30:00-05:00",
            "deliver": ["local"],
        }
    ]
    jobs.TICKER_INTERVAL_SECONDS = 60
    jobs.get_ticker_heartbeat_age = lambda: 1
    jobs.get_ticker_success_age = lambda: 1
    gateway = types.ModuleType("hermes_cli.gateway")
    gateway.find_gateway_pids = lambda: []

    stubs = {
        "hermes_cli": hermes_cli,
        "hermes_cli.colors": colors,
        "hermes_cli.gateway": gateway,
        "cron": cron_package,
        "cron.lifecycle_guard": lifecycle_guard,
        "cron.jobs": jobs,
    }
    sys.modules.update(stubs)
    spec = importlib.util.spec_from_file_location(
        "hermes_cli.cron", source / "hermes_cli" / "cron.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load hermes_cli.cron")
    module = importlib.util.module_from_spec(spec)
    sys.modules["hermes_cli.cron"] = module
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(HERMES_SOURCE, "set HERMES_SOURCE to the pinned Hermes checkout")
class ExternalExecutorHealthTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cron = _load_cron_module(Path(HERMES_SOURCE))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        cron_dir = self.home / "cron"
        cron_dir.mkdir()
        (cron_dir / "executor.json").write_text(
            json.dumps(
                {
                    "kind": "systemd",
                    "unit": "hermes-radar-cron-tick.timer",
                }
            )
            + "\n",
            encoding="utf-8",
        )

    def _capture(self, function, returncode: int) -> str:
        output = io.StringIO()
        completed = subprocess.CompletedProcess([], returncode)
        with (
            patch.dict(os.environ, {"HERMES_HOME": str(self.home)}, clear=False),
            patch("subprocess.run", return_value=completed),
            contextlib.redirect_stdout(output),
        ):
            function()
        return output.getvalue()

    def test_status_reports_active_systemd_timer(self):
        output = self._capture(self.cron.cron_status, returncode=0)
        self.assertIn("External cron executor is running", output)
        self.assertIn("hermes-radar-cron-tick.timer", output)
        self.assertNotIn("Gateway is not running", output)

    def test_list_suppresses_gateway_warning_for_active_timer(self):
        output = self._capture(self.cron.cron_list, returncode=0)
        self.assertIn("External cron executor is running", output)
        self.assertNotIn("Gateway is not running", output)

    def test_status_names_configured_but_inactive_timer(self):
        output = self._capture(self.cron.cron_status, returncode=3)
        self.assertIn("External cron executor is not running", output)
        self.assertIn("hermes-radar-cron-tick.timer", output)
        self.assertNotIn("Gateway is not running", output)

    def test_missing_marker_preserves_gateway_warning(self):
        (self.home / "cron" / "executor.json").unlink()
        output = self._capture(self.cron.cron_status, returncode=0)
        self.assertIn("Gateway is not running", output)

    def test_running_gateway_takes_precedence(self):
        gateway = sys.modules["hermes_cli.gateway"]
        with patch.object(gateway, "find_gateway_pids", return_value=[1234]):
            output = self._capture(self.cron.cron_status, returncode=3)
        self.assertIn("Gateway is running", output)
        self.assertNotIn("External cron executor", output)


if __name__ == "__main__":
    unittest.main()
