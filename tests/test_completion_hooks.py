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
HOOK = ROOT / "scripts/codex-validate-stop"
BASH = shutil.which("bash")
if BASH is None:
    raise RuntimeError("bash is required for completion-hook tests")


def write_command(path, name, exit_code=0, stdout="", stderr="", log_name=None):
    command = path / name
    label = log_name or name
    command.write_text(
        f"#!{BASH}\n"
        f'printf \'{label} %s\\n\' "$*" >>"$COMPLETION_TEST_LOG"\n'
        f"printf '%b' {stdout!r}\n"
        f"printf '%b' {stderr!r} >&2\n"
        f"exit {exit_code}\n"
    )
    command.chmod(command.stat().st_mode | stat.S_IXUSR)
    return command


def run_hook(hey_exit=0, output="", cwd=ROOT):
    with tempfile.TemporaryDirectory() as directory:
        temporary = pathlib.Path(directory)
        log = temporary / "commands.log"
        hey = write_command(temporary, "hey", hey_exit, stdout=output)
        result = subprocess.run(
            ["bash", str(HOOK)],
            cwd=ROOT,
            env={
                **os.environ,
                "CODEX_STOP_HEY": str(hey),
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
            "primary=$(git worktree list --porcelain | sed -n 's/^worktree //p' | head -n 1) && bash \"$primary/scripts/codex-stop-dispatch\" scripts/codex-validate-stop",
        )
        self.assertEqual(hook["timeout"], 1200)

    @unittest.skipUnless(
        sys.platform == "darwin" and "NIX_BUILD_TOP" not in os.environ,
        "Darwin host-specific GitHub authentication",
    )
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
                f"#!{BASH}\n"
                'printf \'gh %s\\n\' "$*" >>"$HEY_AUTH_TEST_LOG"\n'
                'test "$1 $2" = "auth token"\n'
                "printf 'test-token\\n'\n"
            )
            gh.chmod(gh.stat().st_mode | stat.S_IXUSR)

            hostname = fake_bin / "hostname"
            hostname.write_text(
                f"#!{BASH}\n"
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
                f"#!{BASH}\n"
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
                f"#!{BASH}\n"
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
                        "main check --worktree"
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
                and all(
                    line.startswith("nix authenticated ") for line in flake_nix_commands
                ),
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

    def test_codex_wrapper_maps_hey_failure_to_json(self):
        result, commands = run_hook(hey_exit=1, output="specific reason\n")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(
            json.loads(result.stdout),
            {"decision": "block", "reason": "specific reason"},
        )
        self.assertEqual(commands, ["hey check --worktree"])

    def test_codex_wrapper_falls_back_when_hey_output_is_empty(self):
        result, _ = run_hook(hey_exit=1)

        self.assertEqual(
            json.loads(result.stdout),
            {
                "decision": "block",
                "reason": "hey check --worktree failed; fix it before stopping.",
            },
        )

    def test_codex_wrapper_allows_success(self):
        result, commands = run_hook()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(commands, ["hey check --worktree"])

    def test_codex_wrapper_is_inactive_outside_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            result, commands = run_hook(
                hey_exit=1, output="must not run", cwd=directory
            )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(commands, [])


@unittest.skipUnless(shutil.which("nu"), "Nushell is required for hey check tests")
class HeyCheckTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands.log"
        (self.root / "flake.nix").write_text("{}\n")
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        write_command(self.bin, "nix", stdout="/fake/config\n")
        write_command(self.bin, "prek")
        write_command(self.bin, "gh", exit_code=1)

    def run_check(self, *args):
        result = subprocess.run(
            [
                "nu",
                "--no-config-file",
                "--commands",
                f"source {ROOT / 'bin/hey.d/flake.nu'}; main check " + " ".join(args),
            ],
            cwd=self.root,
            env={
                **os.environ,
                "FLAKE_DIR": str(self.root),
                "COMPLETION_TEST_LOG": str(self.log),
                "PATH": f"{self.bin}:{os.environ['PATH']}",
            },
            capture_output=True,
            text=True,
        )
        return result, self.log.read_text().splitlines()

    def test_default_runs_scoped_hooks_once_without_broad_checks(self):
        (self.root / "selected.md").write_text("selected\n")
        (self.root / "unrelated.nix").write_text("{}\n")
        result, commands = self.run_check("--worktree", "selected.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            [line for line in commands if line.startswith("prek ")],
            [
                "prek --config /fake/config run --stage pre-commit --files selected.md --no-progress"
            ],
        )
        self.assertEqual(
            [line for line in commands if line.startswith("nix ")],
            [
                "nix eval --raw --impure --expr builtins.currentSystem",
                "nix eval --raw --impure --expr builtins.currentSystem",
                "nix build .#pre-commit-config --no-link --print-out-paths",
            ],
        )

    def test_empty_scope_does_not_build_config_or_run_hooks(self):
        result, commands = self.run_check("--worktree", "missing.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(
            any("nix build" in line or line.startswith("prek ") for line in commands)
        )
        self.assertFalse(any("flake check" in line for line in commands))

    def test_hook_failure_blocks_completion(self):
        write_command(self.bin, "prek", exit_code=1, stderr="lint failed\n")
        result, _ = self.run_check("--worktree", "flake.nix")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("lint failed", result.stderr)

    @unittest.skipUnless(sys.platform == "linux", "Linux full-check path")
    def test_full_mode_keeps_flake_check_and_propagates_failure(self):
        write_command(self.bin, "nix", exit_code=1)
        result, commands = self.run_check("--full", "--worktree", "missing.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nix flake check", commands)


if __name__ == "__main__":
    unittest.main()
