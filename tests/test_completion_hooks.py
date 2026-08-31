import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKER = ROOT / "scripts/completion-check"
HOOK = ROOT / "scripts/codex-validate-stop"


def write_command(path, name, exit_code=0, stdout="", stderr="", log_name=None):
    command = path / name
    label = log_name or name
    command.write_text(
        "#!/usr/bin/env bash\n"
        f'printf \'{label} %s\\n\' "$*" >>"$COMPLETION_TEST_LOG"\n'
        f"printf '%b' {stdout!r}\n"
        f"printf '%b' {stderr!r} >&2\n"
        f"exit {exit_code}\n"
    )
    command.chmod(command.stat().st_mode | stat.S_IXUSR)
    return command


def run_checker(python_exit=0, hey_exit=0):
    with tempfile.TemporaryDirectory() as directory:
        temporary = pathlib.Path(directory)
        log = temporary / "commands.log"
        python = write_command(temporary, "python", python_exit, stderr="python output\n")
        hey = write_command(temporary, "hey", hey_exit, stderr="hey output\n")
        result = subprocess.run(
            ["bash", str(CHECKER)],
            cwd=temporary,
            env={
                **os.environ,
                "COMPLETION_CHECK_HEY": str(hey),
                "COMPLETION_CHECK_PYTHON": str(python),
                "COMPLETION_TEST_LOG": str(log),
            },
            capture_output=True,
            text=True,
        )
        commands = log.read_text().splitlines() if log.exists() else []
        return result, commands


def run_hook(checker_exit=0, reason="", cwd=ROOT):
    with tempfile.TemporaryDirectory() as directory:
        temporary = pathlib.Path(directory)
        log = temporary / "commands.log"
        checker = write_command(temporary, "checker", checker_exit, stdout=reason)
        result = subprocess.run(
            ["bash", str(HOOK)],
            cwd=ROOT,
            env={
                **os.environ,
                "CODEX_STOP_CHECKER": str(checker),
                "CODEX_STOP_HEY": "/usr/bin/true",
                "CODEX_STOP_PYTHON": "/usr/bin/true",
                "COMPLETION_TEST_LOG": str(log),
            },
            input=json.dumps({"cwd": str(cwd), "hook_event_name": "Stop"}),
            capture_output=True,
            text=True,
        )
        commands = log.read_text().splitlines() if log.exists() else []
        return result, commands


class CompletionHookTests(unittest.TestCase):
    def test_repository_stop_hook_config_is_unchanged(self):
        config = json.loads((ROOT / ".codex/hooks.json").read_text())
        hook = config["hooks"]["Stop"][0]["hooks"][0]

        self.assertEqual(hook["type"], "command")
        self.assertEqual(
            hook["command"],
            'primary=$(git worktree list --porcelain | sed -n \'s/^worktree //p\' | head -n 1) && bash "$primary/scripts/codex-stop-dispatch" scripts/codex-validate-stop',
        )
        self.assertEqual(hook["timeout"], 1200)

    def test_shared_checker_runs_regressions_then_hey_check(self):
        result, commands = run_checker()

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

    def test_shared_checker_defaults_to_checkout_local_hey(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = pathlib.Path(directory)
            checkout = temporary / "checkout"
            scripts = checkout / "scripts"
            local_bin = checkout / "bin"
            ambient_bin = temporary / "ambient-bin"
            scripts.mkdir(parents=True)
            local_bin.mkdir()
            ambient_bin.mkdir()
            log = temporary / "commands.log"
            checker = scripts / "completion-check"
            checker.write_text(
                CHECKER.read_text().replace(
                    'export PATH="/run/current-system/sw/bin:$PATH"',
                    'export PATH="$PATH"',
                )
            )
            checker.chmod(checker.stat().st_mode | stat.S_IXUSR)
            python = write_command(temporary, "python", stderr="python output\n")
            write_command(
                local_bin,
                "hey",
                stderr="local hey output\n",
                log_name="local-hey",
            )
            write_command(
                ambient_bin,
                "hey",
                exit_code=41,
                stderr="ambient hey output\n",
                log_name="ambient-hey",
            )
            env = {
                **os.environ,
                "COMPLETION_CHECK_PYTHON": str(python),
                "COMPLETION_TEST_LOG": str(log),
                "PATH": f"{ambient_bin}:/usr/bin:/bin",
            }
            env.pop("COMPLETION_CHECK_HEY", None)

            result = subprocess.run(
                ["/bin/bash", str(checker)],
                cwd=temporary,
                env=env,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "python output\nlocal hey output\n")
            self.assertEqual(
                log.read_text().splitlines(),
                [
                    "python -m unittest discover -s tests -p test_*.py",
                    "local-hey check",
                ],
            )

    def test_shared_checker_reports_regression_failure(self):
        result, commands = run_checker(python_exit=1)

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "Dotfiles regression tests failed; fix them before stopping.\n")
        self.assertEqual(result.stderr, "python output\n")
        self.assertEqual(commands, ["python -m unittest discover -s tests -p test_*.py"])

    def test_shared_checker_prefers_system_nix_path(self):
        # The official-installer profile nix (2.25) shadows the nix-darwin
        # system nix (2.35) on ambient PATH, and the older nix rejects the
        # committed skills-catalog path input when updating the lock. The
        # checker must run tests with the system-managed toolchain first,
        # mirroring bin/hey.
        with tempfile.TemporaryDirectory() as directory:
            temporary = pathlib.Path(directory)
            log = temporary / "commands.log"
            python = write_command(temporary, "python")
            hey = write_command(temporary, "hey")
            result = subprocess.run(
                ["bash", str(CHECKER)],
                cwd=temporary,
                env={
                    **os.environ,
                    "COMPLETION_CHECK_HEY": str(hey),
                    "COMPLETION_CHECK_PYTHON": str(python),
                    "COMPLETION_TEST_LOG": str(log),
                    "PATH": "/nix/var/nix/profiles/default/bin:/usr/bin:/bin",
                },
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                log.read_text().splitlines(),
                [
                    "python -m unittest discover -s tests -p test_*.py",
                    "hey check",
                ],
            )


    def test_shared_checker_skips_emscripten_python(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = pathlib.Path(directory)
            log = temporary / "commands.log"
            bindir = temporary / "bin"
            bindir.mkdir()
            emscripten = bindir / "python3.13"
            emscripten.write_text(
                "#!/usr/bin/env bash\n"
                'printf \'emscripten %s\\n\' "$*" >>"$COMPLETION_TEST_LOG"\n'
                'if [ "$1" = "-c" ]; then\n'
                "  exit 1\n"
                "fi\n"
                "exit 0\n"
            )
            emscripten.chmod(emscripten.stat().st_mode | stat.S_IXUSR)
            write_command(bindir, "python3", stderr="python output\n")
            hey = write_command(temporary, "hey", stderr="hey output\n")
            env = {
                **os.environ,
                "COMPLETION_CHECK_HEY": str(hey),
                "COMPLETION_TEST_LOG": str(log),
                "PATH": f"{bindir}:/usr/bin:/bin",
            }
            env.pop("COMPLETION_CHECK_PYTHON", None)
            result = subprocess.run(
                ["bash", str(CHECKER)],
                cwd=temporary,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            commands = log.read_text().splitlines()
            self.assertTrue(
                any(line.startswith("emscripten -c ") for line in commands),
                commands,
            )
            self.assertFalse(any(line.startswith("emscripten -m ") for line in commands), commands)
            self.assertIn("python3 -m unittest discover -s tests -p test_*.py", commands)
            self.assertIn("hey check", commands)

    def test_shared_checker_reports_hey_failure(self):
        result, commands = run_checker(hey_exit=1)

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "hey check failed; fix it before stopping.\n")
        self.assertEqual(result.stderr, "python output\nhey output\n")
        self.assertEqual(
            commands,
            ["python -m unittest discover -s tests -p test_*.py", "hey check"],
        )

    def test_codex_wrapper_maps_checker_failure_to_json(self):
        result, commands = run_hook(checker_exit=1, reason="specific reason\n")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(
            json.loads(result.stdout),
            {"decision": "block", "reason": "specific reason"},
        )
        self.assertEqual(commands, ["checker "])

    def test_codex_wrapper_falls_back_when_checker_reason_is_empty(self):
        result, _ = run_hook(checker_exit=1)

        self.assertEqual(
            json.loads(result.stdout),
            {
                "decision": "block",
                "reason": "Completion checks failed; fix them before stopping.",
            },
        )

    def test_codex_wrapper_allows_success(self):
        result, commands = run_hook()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(commands, ["checker "])

    def test_codex_wrapper_is_inactive_outside_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            result, commands = run_hook(checker_exit=1, reason="must not run", cwd=directory)

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(commands, [])

    def test_bun_completion_gate_contract(self):
        result = subprocess.run(
            ["bun", "test", "tests/omp_completion_gate.test.js"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
