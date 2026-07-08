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


class BootstrapAgentSelectionTest(unittest.TestCase):
    def run_bootstrap(self, env: dict[str, str] | None = None, commands: set[str] | None = None):
        created: list[tuple[str, str]] = []
        renamed: list[tuple[str, str]] = []
        ran: list[tuple[str, str]] = []

        def fake_tab_create(workspace_id: str, cwd: str, label: str) -> str:
            self.assertEqual(workspace_id, "workspace-1")
            self.assertEqual(cwd, "/repo")
            pane = f"pane-{len(created) + 1}"
            created.append((label, pane))
            return pane

        with patch.dict(os.environ, env or {}, clear=True), patch.object(
            dev_layout,
            "context",
            return_value={"workspace_id": "workspace-1", "workspace_cwd": "/repo"},
        ), patch.object(dev_layout, "command_exists", side_effect=(commands or set()).__contains__), patch.object(
            dev_layout, "tab_create", side_effect=fake_tab_create
        ), patch.object(
            dev_layout, "pane_rename", side_effect=lambda pane, label: renamed.append((pane, label))
        ), patch.object(
            dev_layout, "pane_run", side_effect=lambda pane, command: ran.append((pane, command))
        ), patch.object(
            dev_layout, "hunk_command", return_value="hunk --worktree"
        ), patch.object(
            dev_layout, "run_json"
        ):
            dev_layout.bootstrap()

        return created, renamed, ran

    def test_bootstrap_uses_pi_when_no_main_agent_is_selected(self) -> None:
        created, renamed, ran = self.run_bootstrap(commands={"pi"})

        self.assertEqual([label for label, _ in created], ["pi", "hunk", "shell"])
        self.assertEqual(renamed[0], ("pane-1", "pi"))
        self.assertEqual(ran[0], ("pane-1", "pi"))

    def test_bootstrap_uses_omp_when_selected(self) -> None:
        created, renamed, ran = self.run_bootstrap(env={"HERDR_MAIN_CODING_AGENT": "omp"}, commands={"pi", "omp"})

        self.assertEqual([label for label, _ in created], ["omp", "hunk", "shell"])
        self.assertEqual(renamed[0], ("pane-1", "omp"))
        self.assertEqual(ran[0], ("pane-1", "omp"))

    def test_bootstrap_skips_selected_agent_when_command_is_missing(self) -> None:
        created, renamed, ran = self.run_bootstrap(env={"HERDR_MAIN_CODING_AGENT": "omp"}, commands={"pi"})

        self.assertEqual([label for label, _ in created], ["hunk", "shell"])
        self.assertNotIn(("pane-1", "pi"), renamed)
        self.assertNotIn(("pane-1", "pi"), ran)


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
