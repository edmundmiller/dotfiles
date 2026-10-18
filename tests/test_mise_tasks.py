"""Public mise/hey contracts, exercised in disposable projects."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(
    shutil.which("mise") and shutil.which("nu"), "mise and nu required"
)
class MiseTasksTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project with spaces"
        self.root.mkdir()
        self.env = os.environ | {
            "MISE_TRUSTED_CONFIG_PATHS": str(self.root),
            "MISE_DATA_DIR": str(Path(self.temp.name) / "mise-data"),
            "MISE_STATE_DIR": str(Path(self.temp.name) / "mise-state"),
            "MISE_CACHE_DIR": str(Path(self.temp.name) / "mise-cache"),
            "MISE_GLOBAL_CONFIG_FILE": "/dev/null",
            "MISE_SYSTEM_CONFIG_FILE": "/dev/null",
            "MISE_TASK_OUTPUT": "interleave",
            "MISE_AUTO_INSTALL": "0",
        }

    def run_command(self, *args, cwd=None):
        return subprocess.run(
            args,
            cwd=cwd or self.root,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )

    def copy_project(self):
        shutil.copy2(ROOT / "mise.toml", self.root)
        shutil.copytree(ROOT / "mise-tasks", self.root / "mise-tasks")
        (self.root / "bin").mkdir()
        shutil.copy2(ROOT / "bin/hey", self.root / "bin/hey")
        shutil.copytree(ROOT / "scripts/nu", self.root / "scripts/nu")
        shutil.copy2(ROOT / "scripts/validation.py", self.root / "scripts")

    def test_hey_uses_current_project_and_preserves_arguments_and_failure(self):
        (self.root / "mise.toml").write_text(
            '[tasks.echo]\nraw_args = true\nraw = true\nfile = "echo.sh"\n'
        )
        script = self.root / "echo.sh"
        script.write_text(f'#!{shutil.which("bash")}\nprintf "<%s>\\n" "$@"\nexit 23\n')
        script.chmod(0o755)
        self.env["DOTFILES"] = str(ROOT)
        self.env["FLAKE_DIR"] = str(ROOT)
        result = self.run_command(
            str(ROOT / "bin/hey"), "echo", "a b", "--help", "$(false)"
        )
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(result.stdout, "<a b>\n<--help>\n<$(false)>\n")

    def test_check_matches_ci_from_subdirectory_despite_stale_flake_dir(self):
        self.copy_project()
        self.run_command("git", "init", "--quiet")
        initial = self.run_command(
            "git",
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "--allow-empty",
            "--no-gpg-sign",
            "-m",
            "base",
        )
        self.assertEqual(initial.returncode, 0, initial.stderr)
        (self.root / "owned space.md").write_text("changed\n")
        nested = self.root / "nested"
        nested.mkdir()
        self.env["FLAKE_DIR"] = str(ROOT)
        direct = self.run_command(
            "python3", "scripts/validation.py", "--plan", "owned space.md"
        )
        self.assertEqual(direct.returncode, 0, direct.stderr)
        expected = json.loads(direct.stdout)
        self.assertEqual(expected["files"], ["owned space.md"])
        for command in [
            ("mise", "run", "check"),
            (str(self.root / "bin/hey"), "check"),
        ]:
            with self.subTest(command=command):
                result = self.run_command(
                    *command, "--plan", "owned space.md", cwd=nested
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), expected)

    def test_task_names_and_aliases_reach_the_parser_without_running_operations(self):
        self.copy_project()
        for task, parameter in [
            ("re", "action"),
            ("nuc", "worktree_mode"),
            ("deploy", "host"),
            ("nuc:worktree", "configuration"),
            ("nuc-worktree", "configuration"),
            ("nuc-wt", "dry-activate"),
            ("nuc:logs", "unit"),
            ("nuc-logs", "unit"),
            ("ergodox:flash", "hex"),
            ("ergodox-flash", "hex"),
            ("deploy:agents", "dotfiles_msg"),
            ("agents-rollout", "dotfiles_msg"),
            ("zbench", "args"),
            ("zbench:save", "args"),
            ("u", "inputs"),
        ]:
            with self.subTest(task=task):
                result = self.run_command("mise", "run", task, "--help")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(parameter, result.stdout)
                self.assertIn("Parameters:", result.stdout)

    def test_environment_and_dev_credentials_stay_scoped(self):
        self.copy_project()
        self.env.pop("WORKTRUNK_WORKTREE_PATH", None)
        result = self.run_command(
            "mise",
            "exec",
            "--",
            "bash",
            "-c",
            'test -z "${WORKTRUNK_WORKTREE_PATH+x}" && printenv BEADS_NO_DAEMON',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "1\n")

        # Stand in for Nix's process boundary, without evaluating or activating hosts.
        tools = self.root / "fake-tools"
        tools.mkdir()
        for name, body in {
            "gh": """
[[ "$*" == 'auth token --hostname github.com' ]] || exit 93
case "$TEST_AUTH" in
  available) printf 'fixture-token\\n' ;;
  empty) : ;;
  missing) exit 127 ;;
  failure) printf 'fixture-token\\n'; exit 1 ;;
esac
""",
            "nix": """
expected_config="$TEST_CALLER_CONFIG"
if [[ "$TEST_AUTH" == available ]]; then
  expected_config+=$'\\nextra-access-tokens = github.com=fixture-token'
fi
[[ "${NIX_CONFIG:-}" == "$expected_config" ]] || exit 90
[[ "$1" == develop && "$2" == "$MISE_PROJECT_ROOT#$TEST_SHELL" ]] || exit 91
[[ "$3" == --no-update-lock-file ]] || exit 94
while [[ "$1" != --command ]]; do
  if [[ "$1" == --unset ]]; then shift; unset "$1"; fi
  shift
done
# Nix runs shellHook here, before the command used to restore the caller's config.
[[ -z "${NIX_CONFIG+x}" ]] || exit 92
shift
exec "$@"
""",
        }.items():
            script = tools / name
            script.write_text(
                f"#!{shutil.which('bash')}\nset -euo pipefail\n" + body + "\n"
            )
            script.chmod(0o755)
        self.env["PATH"] = f"{tools}:{self.env['PATH']}"
        for auth in ("available", "empty", "missing", "failure"):
            for configured in (False, True):
                for shell in ("default", "full"):
                    with self.subTest(auth=auth, configured=configured, shell=shell):
                        caller_config = (
                            "keep-going = true\naccess-tokens = git.example.com=existing-token"
                            if configured
                            else ""
                        )
                        self.env.pop("NIX_CONFIG", None)
                        if configured:
                            self.env["NIX_CONFIG"] = caller_config
                        self.env.update(
                            TEST_AUTH=auth,
                            TEST_CALLER_CONFIG=caller_config,
                            TEST_SHELL=shell,
                        )
                        result = self.run_command(
                            "mise",
                            "run",
                            "dev",
                            shell,
                            "bash",
                            "-c",
                            'test "$NIX_CONFIG" = "$TEST_CALLER_CONFIG" && '
                            'test -z "${DOTFILES_DEV_NIX_CONFIG+x}" && '
                            'printf "%s\\n" "$NIX_CONFIG"',
                        )
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stdout, caller_config + "\n")
                        self.assertNotIn("fixture-token", result.stdout + result.stderr)
        invalid = self.run_command("mise", "run", "dev", "unknown")
        self.assertEqual(invalid.returncode, 2, invalid.stderr)


if __name__ == "__main__":
    unittest.main()
