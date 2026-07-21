import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / "skills/conditional/herdr/herdr"
SCRIPTS = SKILL_ROOT / "scripts"
MODULE = ROOT / "modules/shell/herdr/default.nix"
OVERLAY = ROOT / "overlays/herdr/default.nix"

FAKE_HERDR = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ["HERDR_TEST_LOG"]).open("a") as stream:
    stream.write(json.dumps(args) + "\\n")

if args[:2] == ["workspace", "create"]:
    print(json.dumps({
        "result": {
            "workspace": {"workspace_id": "w7"},
            "tab": {"tab_id": "w7:t1"},
            "root_pane": {"pane_id": "w7:p3"},
        }
    }))
else:
    print(json.dumps({"result": {}}))
"""


class HerdrAgentAutomationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.temp = Path(self.tempdir.name)
        self.repo = self.temp / "repo"
        self.repo.mkdir()
        self.prompt = self.temp / "prompt.md"
        self.prompt.write_text("Review current diff.\n")
        self.log = self.temp / "herdr.jsonl"
        fake = self.temp / "herdr"
        fake.write_text(FAKE_HERDR)
        fake.chmod(0o755)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def environment(self, *, managed: bool = True) -> dict[str, str]:
        env = os.environ.copy()
        env["PATH"] = f"{self.temp}{os.pathsep}{env['PATH']}"
        env["HERDR_TEST_LOG"] = str(self.log)
        if managed:
            env["HERDR_ENV"] = "1"
        else:
            env.pop("HERDR_ENV", None)
        return env

    def run_helper(
        self,
        name: str,
        *args: str,
        managed: bool = True,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(SCRIPTS / name), *args],
            capture_output=True,
            text=True,
            env=self.environment(managed=managed),
        )

    def commands(self) -> list[list[str]]:
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_start_workspace_uses_existing_pane_agent_facade(self) -> None:
        result = self.run_helper(
            "start_pi_workspace.py",
            "--cwd",
            str(self.repo),
            "--label",
            "review",
            "--prompt-file",
            str(self.prompt),
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            {
                "workspace_id": "w7",
                "pane_id": "w7:p3",
                "agent_name": "pi-w7-p3",
            },
            json.loads(result.stdout),
        )
        self.assertEqual(
            [
                [
                    "workspace",
                    "create",
                    "--cwd",
                    str(self.repo.resolve()),
                    "--label",
                    "review",
                    "--no-focus",
                ],
                [
                    "agent",
                    "start",
                    "pi-w7-p3",
                    "--kind",
                    "pi",
                    "--pane",
                    "w7:p3",
                    "--timeout",
                    "30000",
                ],
                ["agent", "prompt", "pi-w7-p3", "Review current diff.\n"],
            ],
            self.commands(),
        )

    def test_send_prompt_starts_and_prompts_agent_atomically(self) -> None:
        result = self.run_helper(
            "send_prompt_to_pane.py",
            "--pane",
            "w2:p4",
            "--start-pi",
            "--prompt-file",
            str(self.prompt),
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            [
                [
                    "agent",
                    "start",
                    "pi-w2-p4",
                    "--kind",
                    "pi",
                    "--pane",
                    "w2:p4",
                    "--timeout",
                    "30000",
                ],
                ["agent", "prompt", "pi-w2-p4", "Review current diff.\n"],
            ],
            self.commands(),
        )

    def test_monitor_uses_agent_wait_and_agent_read(self) -> None:
        result = self.run_helper(
            "monitor_pane.py",
            "--pane",
            "w2:p4",
            "--wait-status",
            "done",
            "--source",
            "recent-unwrapped",
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            [
                ["agent", "get", "w2:p4"],
                [
                    "agent",
                    "wait",
                    "w2:p4",
                    "--until",
                    "done",
                    "--timeout",
                    "120000",
                ],
                [
                    "agent",
                    "read",
                    "w2:p4",
                    "--source",
                    "recent-unwrapped",
                    "--lines",
                    "80",
                ],
            ],
            self.commands(),
        )

    def test_mutating_helper_rejects_non_herdr_shell(self) -> None:
        result = self.run_helper(
            "start_pi_workspace.py",
            "--cwd",
            str(self.repo),
            "--label",
            "review",
            "--prompt-file",
            str(self.prompt),
            managed=False,
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("HERDR_ENV=1", result.stderr)
        self.assertFalse(self.log.exists())

    def test_extract_ids_tracks_moved_pane_id(self) -> None:
        payload = {
            "result": {
                "move_result": {
                    "previous_pane_id": "w1:p2",
                    "pane": {"pane_id": "w2:p9"},
                }
            }
        }
        result = subprocess.run(
            ["python3", str(SCRIPTS / "extract_ids.py"), "pane"],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
        )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("w2:p9", result.stdout.strip())

    def test_skill_docs_use_the_v075_automation_contract(self) -> None:
        maintained = "\n".join(
            path.read_text()
            for path in (
                SKILL_ROOT / "SKILL.md",
                SKILL_ROOT / "references/cli-map.md",
                SKILL_ROOT / "references/recipes.md",
                SKILL_ROOT / "references/pi-workspace.md",
            )
        )

        for phrase in (
            "herdr agent prompt",
            "herdr agent send-keys",
            "herdr pane wait-output",
            "--kind codex --pane",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, maintained)
        for stale in (
            "herdr agent send ",
            "herdr wait agent-status",
            "herdr wait output",
        ):
            with self.subTest(stale=stale):
                self.assertNotIn(stale, maintained)

    def test_local_plugins_are_linked_through_the_global_registry_cli(self) -> None:
        module = MODULE.read_text()

        self.assertIn('plugin link "$plugin_root"', module)
        self.assertIn("HERDR_SOCKET_PATH", module)
        self.assertNotIn("registry.write_text", module)
        self.assertNotIn('"startup": manifest.get("startup", [])', module)

    def test_overlay_pins_v075_without_upstreamed_cursor_patch(self) -> None:
        overlay = OVERLAY.read_text()

        self.assertIn("ef4c23f5775bb8cfec05f05d0844226ff959a07a", overlay)
        self.assertNotIn("0010-guard-resize-cursor-scrollback.patch", overlay)
        self.assertFalse(
            (
                ROOT
                / "overlays/herdr/patches/0010-guard-resize-cursor-scrollback.patch"
            ).exists()
        )


if __name__ == "__main__":
    unittest.main()
