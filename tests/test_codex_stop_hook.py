import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
HOOK = ROOT / "scripts/codex-validate-stop"


def write_command(path, name, exit_code=0):
    command = path / name
    command.write_text(
        "#!/usr/bin/env bash\n"
        f'printf \'{name} %s\\n\' "$*" >>"$CODEX_STOP_LOG"\n'
        f"printf '{name} output\\n'\n"
        f"exit {exit_code}\n"
    )
    command.chmod(command.stat().st_mode | stat.S_IXUSR)
    return command


def run_hook(python_exit=0, hey_exit=0):
    directory = tempfile.TemporaryDirectory()
    temporary = pathlib.Path(directory.name)
    log = temporary / "commands.log"
    python = write_command(temporary, "python", python_exit)
    hey = write_command(temporary, "hey", hey_exit)
    env = {
        **os.environ,
        "CODEX_STOP_HEY": str(hey),
        "CODEX_STOP_LOG": str(log),
        "CODEX_STOP_PYTHON": str(python),
    }
    result = subprocess.run(
        ["bash", str(HOOK)],
        cwd=ROOT,
        env=env,
        input=json.dumps({"cwd": str(ROOT), "hook_event_name": "Stop"}),
        capture_output=True,
        text=True,
    )
    commands = log.read_text().splitlines()
    directory.cleanup()
    return result, commands


class CodexStopHookTests(unittest.TestCase):
    def test_repository_stop_hook_runs_validation_script(self):
        config = json.loads((ROOT / ".codex/hooks.json").read_text())
        hook = config["hooks"]["Stop"][0]["hooks"][0]

        self.assertEqual(hook["type"], "command")
        self.assertIn("scripts/codex-validate-stop", hook["command"])

    def test_stop_hook_runs_regressions_then_hey_check(self):
        result, commands = run_hook()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "python output\nhey output\n")
        self.assertEqual(
            commands,
            [
                "python -m unittest discover -s tests -p test_*.py",
                "hey check",
            ],
        )

    def test_stop_hook_blocks_when_regressions_fail(self):
        result, commands = run_hook(python_exit=1)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "python output\n")
        self.assertEqual(
            json.loads(result.stdout),
            {
                "decision": "block",
                "reason": "Dotfiles regression tests failed; fix them before stopping.",
            },
        )
        self.assertEqual(
            commands,
            ["python -m unittest discover -s tests -p test_*.py"],
        )

    def test_stop_hook_blocks_when_hey_check_fails(self):
        result, commands = run_hook(hey_exit=1)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "python output\nhey output\n")
        self.assertEqual(
            json.loads(result.stdout),
            {
                "decision": "block",
                "reason": "hey check failed; fix it before stopping.",
            },
        )
        self.assertEqual(
            commands,
            [
                "python -m unittest discover -s tests -p test_*.py",
                "hey check",
            ],
        )


if __name__ == "__main__":
    unittest.main()
