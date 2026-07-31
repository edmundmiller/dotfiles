import os
import sys
import unittest
import tomllib
import tempfile
import threading
import time
from collections.abc import Callable
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import dev_layout


class Completed:
    def __init__(self, returncode: int, stdout: str = "") -> None:
        self.returncode = returncode
        self.stdout = stdout


class BootstrapLayoutTest(unittest.TestCase):
    def run_bootstrap(
        self,
        *,
        env: dict[str, str] | None = None,
        context: dict[str, str] | None = None,
        existing: dict[str, str] | None = None,
        tab_ids: set[str] | None = None,
        before_pane_run: Callable[[str, str], None] | None = None,
    ):
        created: list[tuple[str, str]] = []
        ran: list[tuple[str, str]] = []
        calls: list[list[str]] = []
        ctx = {"workspace_id": "workspace-1", "workspace_cwd": "/repo"}
        ctx.update(context or {})

        def fake_tab_create(workspace_id: str, cwd: str, label: str) -> tuple[str, str]:
            self.assertEqual(workspace_id, "workspace-1")
            self.assertEqual(cwd, ctx["workspace_cwd"])
            created.append((label, cwd))
            return f"tab-{label}", f"pane-{label}"

        def fake_pane_run(pane: str, command: str) -> None:
            if before_pane_run:
                before_pane_run(pane, command)
            ran.append((pane, command))

        with (
            patch.dict(os.environ, env or {}, clear=True),
            patch.object(dev_layout, "context", return_value=ctx),
            patch.object(dev_layout, "command_exists", return_value=True),
            patch.object(
                dev_layout,
                "workspace_tabs",
                return_value=(
                    existing or {},
                    tab_ids or set((existing or {}).values()),
                ),
            ),
            patch.object(dev_layout, "tab_create", side_effect=fake_tab_create),
            patch.object(dev_layout, "pane_rename"),
            patch.object(dev_layout, "pane_run", side_effect=fake_pane_run),
            patch.object(dev_layout, "hunk_command", return_value="hunk --worktree"),
            patch.object(
                dev_layout,
                "run_json",
                side_effect=lambda args: calls.append(args) or {},
            ),
        ):
            dev_layout.bootstrap()

        return created, ran, calls

    def test_bootstrap_creates_only_codex_and_hunk_and_focuses_codex(self) -> None:
        created, ran, calls = self.run_bootstrap()

        self.assertEqual(created, [("codex", "/repo"), ("hunk", "/repo")])
        self.assertEqual(
            ran, [("pane-codex", "codex"), ("pane-hunk", "hunk --worktree")]
        )
        self.assertIn(["tab", "focus", "tab-codex"], calls)

    def test_bootstrap_is_idempotent(self) -> None:
        created, ran, calls = self.run_bootstrap(
            existing={"codex": "tab-codex", "hunk": "tab-hunk"}
        )

        self.assertEqual(created, [])
        self.assertEqual(ran, [])
        self.assertEqual(calls, [["tab", "focus", "tab-codex"]])

    def test_creation_event_closes_only_the_initial_tab(self) -> None:
        _, _, calls = self.run_bootstrap(
            env={"HERDR_PLUGIN_EVENT": "workspace.created"},
            context={"tab_id": "tab-initial"},
            tab_ids={"tab-initial"},
        )

        self.assertIn(["tab", "close", "tab-initial"], calls)
        self.assertIn(["tab", "focus", "tab-codex"], calls)

    @unittest.expectedFailure
    def test_bootstrap_seeds_qmd_before_launching_codex(self) -> None:
        with tempfile.TemporaryDirectory() as repo:
            scripts = Path(repo, "scripts")
            scripts.mkdir()
            marker = Path(repo, ".qmd-seeded")
            seeder = scripts / "qmd-seed-worktree.sh"
            seeder.write_text("#!/bin/sh\nset -eu\ntouch .qmd-seeded\n")
            seeder.chmod(0o755)

            def assert_seeded_before_codex(_pane: str, command: str) -> None:
                if command == "codex":
                    self.assertTrue(marker.exists())

            self.run_bootstrap(
                context={"workspace_cwd": repo},
                before_pane_run=assert_seeded_before_codex,
            )

    def test_workspace_lock_serializes_concurrent_hooks(self) -> None:
        intervals: list[tuple[float, float]] = []
        barrier = threading.Barrier(3)

        def run() -> None:
            barrier.wait()
            with dev_layout.workspace_lock("workspace-1"):
                started = time.monotonic()
                time.sleep(0.05)
                intervals.append((started, time.monotonic()))

        with tempfile.TemporaryDirectory() as lock_dir:
            with patch.object(dev_layout.tempfile, "gettempdir", return_value=lock_dir):
                threads = [threading.Thread(target=run) for _ in range(2)]
                for thread in threads:
                    thread.start()
                barrier.wait()
                for thread in threads:
                    thread.join()

        first, second = sorted(intervals)
        self.assertLessEqual(first[1], second[0])


class CommandTest(unittest.TestCase):
    def test_pane_run_accepts_empty_success_output(self) -> None:
        with patch("dev_layout.subprocess.run", return_value=Completed(0, "")) as run:
            dev_layout.pane_run("pane-1", "codex")

        self.assertEqual(
            run.call_args.args[0], ["herdr", "pane", "run", "pane-1", "codex"]
        )


class ManifestTest(unittest.TestCase):
    def test_uses_literal_supported_creation_events(self) -> None:
        manifest = tomllib.loads(
            Path(__file__).with_name("herdr-plugin.toml").read_text()
        )

        events = {event["on"] for event in manifest["events"]}
        self.assertEqual(events, {"workspace.created", "worktree.created"})


class HunkThemeArgsTest(unittest.TestCase):
    def test_hunk_theme_override_wins_over_stack_theme(self) -> None:
        with (
            patch.object(sys, "platform", "darwin"),
            patch.dict(
                os.environ,
                {
                    "HUNK_THEME": "catppuccin-frappe",
                    "HUNK_THEME_DARK": "stack-dark",
                    "HUNK_THEME_LIGHT": "stack-light",
                },
                clear=True,
            ),
            patch("dev_layout.subprocess.run", return_value=Completed(0, "true\n")),
        ):
            self.assertEqual(
                dev_layout.hunk_theme_args(),
                ["--theme", "catppuccin-frappe", "--no-transparent-bg"],
            )

    def test_macos_dark_uses_stack_dark_theme(self) -> None:
        with (
            patch.object(sys, "platform", "darwin"),
            patch.dict(
                os.environ,
                {"HUNK_THEME_DARK": "stack-dark", "HUNK_THEME_LIGHT": "stack-light"},
                clear=True,
            ),
            patch("dev_layout.subprocess.run", return_value=Completed(0, "true\n")),
        ):
            self.assertEqual(
                dev_layout.hunk_theme_args(),
                ["--theme", "stack-dark", "--no-transparent-bg"],
            )

    def test_macos_light_uses_stack_light_theme(self) -> None:
        with (
            patch.object(sys, "platform", "darwin"),
            patch.dict(
                os.environ,
                {"HUNK_THEME_DARK": "stack-dark", "HUNK_THEME_LIGHT": "stack-light"},
                clear=True,
            ),
            patch("dev_layout.subprocess.run", return_value=Completed(0, "false\n")),
        ):
            self.assertEqual(
                dev_layout.hunk_theme_args(),
                ["--theme", "stack-light", "--no-transparent-bg"],
            )

    def test_no_theme_when_stack_theme_and_detection_are_missing(self) -> None:
        with (
            patch.object(sys, "platform", "darwin"),
            patch.dict(os.environ, {}, clear=True),
            patch(
                "dev_layout.subprocess.run",
                return_value=Completed(1),
            ),
        ):
            self.assertEqual(dev_layout.hunk_theme_args(), ["--no-transparent-bg"])


if __name__ == "__main__":
    unittest.main()
