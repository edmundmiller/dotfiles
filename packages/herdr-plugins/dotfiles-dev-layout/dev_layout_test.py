import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import dev_layout


class Completed:
    def __init__(self, returncode: int, stdout: str = "") -> None:
        self.returncode = returncode
        self.stdout = stdout


class HunkThemeArgsTest(unittest.TestCase):
    def test_env_override_wins(self) -> None:
        with patch.dict(os.environ, {"HUNK_THEME": "catppuccin-frappe"}):
            self.assertEqual(dev_layout.hunk_theme_args(), ["--theme", "catppuccin-frappe", "--no-transparent-bg"])

    def test_macos_dark_uses_catppuccin_mocha(self) -> None:
        with patch.object(sys, "platform", "darwin"), patch.dict(os.environ, {}, clear=True), patch(
            "subprocess.run",
            return_value=Completed(0, "true\n"),
        ):
            self.assertEqual(dev_layout.hunk_theme_args(), ["--theme", "catppuccin-mocha", "--no-transparent-bg"])

    def test_macos_light_uses_catppuccin_latte_when_system_events_says_false(self) -> None:
        with patch.object(sys, "platform", "darwin"), patch.dict(os.environ, {}, clear=True), patch(
            "subprocess.run",
            return_value=Completed(0, "false\n"),
        ):
            self.assertEqual(dev_layout.hunk_theme_args(), ["--theme", "catppuccin-latte", "--no-transparent-bg"])

    def test_macos_unknown_only_sets_background_policy(self) -> None:
        with patch.object(sys, "platform", "darwin"), patch.dict(os.environ, {}, clear=True), patch(
            "subprocess.run",
            return_value=Completed(1),
        ):
            self.assertEqual(dev_layout.hunk_theme_args(), ["--no-transparent-bg"])


if __name__ == "__main__":
    unittest.main()
