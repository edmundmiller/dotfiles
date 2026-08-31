import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
HOOK = ROOT / "scripts/codex-validate-stop"
DISPATCH = ROOT / "scripts/codex-stop-dispatch"


def write_command(path, name, exit_code=0, stdout=""):
    command = path / name
    command.write_text(
        "#!/usr/bin/env bash\n"
        f'printf \'{name} %s\\n\' "$*" >>"$CODEX_STOP_LOG"\n'
        f"printf '%s' {stdout!r}\n"
        f"exit {exit_code}\n"
    )
    command.chmod(command.stat().st_mode | stat.S_IXUSR)
    return command


def run_hook(hey_exit=0, hey_output="", stop_hook_active=False, serializer=None):
    directory = tempfile.TemporaryDirectory()
    temporary = pathlib.Path(directory.name)
    log = temporary / "commands.log"
    hey = write_command(temporary, "hey", hey_exit, hey_output)
    env = {
        **os.environ,
        "CODEX_STOP_HEY": str(hey),
        "CODEX_STOP_LOG": str(log),
    }
    if serializer:
        env["CODEX_STOP_SERIALIZER"] = serializer
    result = subprocess.run(
        ["bash", str(HOOK)],
        cwd=ROOT,
        env=env,
        input=json.dumps(
            {
                "cwd": str(ROOT),
                "hook_event_name": "Stop",
                "stop_hook_active": stop_hook_active,
            }
        ),
        capture_output=True,
        text=True,
    )
    commands = log.read_text().splitlines() if log.exists() else []
    directory.cleanup()
    return result, commands


class CodexStopHookTests(unittest.TestCase):
    def test_repository_stop_hook_runs_validation_script(self):
        config = json.loads((ROOT / ".codex/hooks.json").read_text())
        hook = config["hooks"]["Stop"][0]["hooks"][0]

        self.assertEqual(hook["type"], "command")
        self.assertIn("scripts/codex-stop-dispatch", hook["command"])
        self.assertIn("scripts/codex-validate-stop", hook["command"])

    def test_dispatcher_stops_forced_continuation_before_worktree_hook(self):
        result = subprocess.run(
            ["bash", str(DISPATCH), "scripts/codex-validate-stop"],
            cwd=ROOT,
            input=json.dumps(
                {
                    "cwd": str(ROOT),
                    "hook_event_name": "Stop",
                    "stop_hook_active": True,
                }
            ),
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_stop_hook_runs_repository_check(self):
        result, commands = run_hook()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")
        self.assertEqual(commands, ["hey check --worktree"])

    def test_stop_hook_blocks_when_hey_check_fails(self):
        reason = "hey check --worktree failed; fix it before stopping."
        result, commands = run_hook(hey_exit=1, hey_output=reason)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")
        self.assertEqual(
            json.loads(result.stdout),
            {
                "decision": "block",
                "reason": reason,
            },
        )
        self.assertEqual(commands, ["hey check --worktree"])

    def test_stop_hook_bounds_large_diagnostics(self):
        result, commands = run_hook(
            hey_exit=1,
            hey_output=("x" * 200_000) + "terminal marker",
        )

        payload = json.loads(result.stdout)
        self.assertEqual(payload["decision"], "block")
        self.assertLessEqual(len(payload["reason"]), 32768)
        self.assertTrue(payload["reason"].endswith("terminal marker"))
        self.assertEqual(commands, ["hey check --worktree"])

    def test_stop_hook_fails_closed_when_diagnostics_cannot_be_serialized(self):
        result, commands = run_hook(
            hey_exit=1,
            hey_output="details",
            serializer="/usr/bin/false",
        )

        self.assertEqual(
            json.loads(result.stdout),
            {
                "decision": "block",
                "reason": "hey check --worktree failed and diagnostics could not be serialized; fix it before stopping.",
            },
        )
        self.assertEqual(commands, ["hey check --worktree"])

    def test_forced_continuation_does_not_block_or_rerun_checks(self):
        result, commands = run_hook(hey_exit=1, stop_hook_active=True)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")
        self.assertEqual(commands, [])


if __name__ == "__main__":
    unittest.main()
