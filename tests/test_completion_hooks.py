import json
import os
import pathlib
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKER = ROOT / "scripts/completion-check"
HOOK = ROOT / "scripts/codex-validate-stop"


def write_command(path, name, exit_code=0, stdout="", stderr=""):
    command = path / name
    command.write_text(
        "#!/usr/bin/env bash\n"
        f'printf \'{name} %s\\n\' "$*" >>"$COMPLETION_TEST_LOG"\n'
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

    def test_shared_checker_defaults_to_repository_hey(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = pathlib.Path(directory)
            repository = temporary / "repository"
            scripts = repository / "scripts"
            scripts.mkdir(parents=True)
            checker = scripts / "completion-check"
            checker.write_text(CHECKER.read_text())
            checker.chmod(checker.stat().st_mode | stat.S_IXUSR)

            log = temporary / "commands.log"
            python = write_command(temporary, "python", stderr="python output\n")
            repository_bin = repository / "bin"
            repository_bin.mkdir()
            write_command(repository_bin, "hey", stderr="repository hey output\n")
            ambient_bin = temporary / "ambient-bin"
            ambient_bin.mkdir()
            write_command(ambient_bin, "hey", exit_code=17, stderr="ambient hey output\n")

            env = {
                **os.environ,
                "COMPLETION_CHECK_PYTHON": str(python),
                "COMPLETION_TEST_LOG": str(log),
                "PATH": f"{ambient_bin}:/usr/bin:/bin",
            }
            env.pop("COMPLETION_CHECK_HEY", None)
            result = subprocess.run(
                ["bash", str(checker)],
                cwd=temporary,
                env=env,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stderr, "python output\nrepository hey output\n")
            self.assertEqual(
                log.read_text().splitlines(),
                [
                    "python -m unittest discover -s tests -p test_*.py",
                    "hey check",
                ],
            )

    @unittest.skipUnless(sys.platform == "darwin", "Darwin-specific GitHub authentication")
    def test_repository_hey_check_authenticates_private_github_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            real_nix = shutil.which("nix")
            self.assertIsNotNone(real_nix)
            temporary = pathlib.Path(directory)
            fake_bin = temporary / "bin"
            fake_bin.mkdir()
            command_log = temporary / "commands.log"
            precommit_config = temporary / "pre-commit-config.json"
            precommit_config.write_text("{}\n")

            gh = fake_bin / "gh"
            gh.write_text(
                "#!/usr/bin/env bash\n"
                'printf \'gh %s\\n\' "$*" >>"$HEY_AUTH_TEST_LOG"\n'
                'test "$1 $2" = "auth token"\n'
                "printf 'test-token\\n'\n"
            )
            gh.chmod(gh.stat().st_mode | stat.S_IXUSR)

            hostname = fake_bin / "hostname"
            hostname.write_text(
                "#!/usr/bin/env bash\n"
                'case "${NIX_CONFIG:-}" in\n'
                "  *'access-tokens = github.com=test-token'*) auth=authenticated ;;\n"
                "  *) auth=unauthenticated ;;\n"
                "esac\n"
                'printf \'hostname %s %s\\n\' "$auth" "$*" >>"$HEY_AUTH_TEST_LOG"\n'
                "printf 'Mac\\n'\n"
            )
            hostname.chmod(hostname.stat().st_mode | stat.S_IXUSR)

            fake_nix = fake_bin / "nix"
            fake_nix.write_text(
                "#!/usr/bin/env bash\n"
                'case "${NIX_CONFIG:-}" in\n'
                "  *'access-tokens = github.com=test-token'*) auth=authenticated ;;\n"
                "  *) auth=unauthenticated ;;\n"
                "esac\n"
                'printf \'nix %s %s\\n\' "$auth" "$*" >>"$HEY_AUTH_TEST_LOG"\n'
                'case " $* " in\n'
                "  *' .#pre-commit-config '*) printf '%s\\n' \"$HEY_AUTH_PRECOMMIT_CONFIG\" ;;\n"
                "esac\n"
            )
            fake_nix.chmod(fake_nix.stat().st_mode | stat.S_IXUSR)

            prek = fake_bin / "prek"
            prek.write_text(
                "#!/usr/bin/env bash\n"
                'case "${NIX_CONFIG:-}" in\n'
                "  *'access-tokens = github.com=test-token'*) auth=authenticated ;;\n"
                "  *) auth=unauthenticated ;;\n"
                "esac\n"
                'printf \'prek %s %s\\n\' "$auth" "$*" >>"$HEY_AUTH_TEST_LOG"\n'
            )
            prek.chmod(prek.stat().st_mode | stat.S_IXUSR)

            result = subprocess.run(
                [
                    real_nix,
                    "shell",
                    "nixpkgs#nushell",
                    "--command",
                    "nu",
                    "--commands",
                    (
                        f"source {ROOT / 'bin/hey.d/common.nu'}; "
                        f"source {ROOT / 'bin/hey.d/flake.nu'}; "
                        "main check"
                    ),
                ],
                cwd=ROOT,
                env={
                    **os.environ,
                    "HEY_AUTH_PRECOMMIT_CONFIG": str(precommit_config),
                    "HEY_AUTH_TEST_LOG": str(command_log),
                    "PATH": f"{fake_bin}:{os.environ['PATH']}",
                },
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            commands = command_log.read_text().splitlines()
            nix_commands = [line for line in commands if line.startswith("nix ")]
            self.assertTrue(nix_commands, commands)
            flake_nix_commands = [line for line in nix_commands if " .#" in line]
            self.assertTrue(
                flake_nix_commands
                and all(line.startswith("nix authenticated ") for line in flake_nix_commands),
                commands,
            )
            platform_nix_commands = [
                line for line in nix_commands if "builtins.currentSystem" in line
            ]
            self.assertTrue(
                platform_nix_commands
                and all(
                    line.startswith("nix unauthenticated ")
                    for line in platform_nix_commands
                ),
                commands,
            )
            prek_commands = [line for line in commands if line.startswith("prek ")]
            self.assertTrue(prek_commands, commands)
            self.assertTrue(
                all(line.startswith("prek unauthenticated ") for line in prek_commands),
                commands,
            )
            self.assertIn("hostname unauthenticated -s", commands)
            self.assertIn("gh auth token", commands)

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
