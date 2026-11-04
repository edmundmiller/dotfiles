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
        empty_config = Path(self.temp.name) / "empty.toml"
        empty_config.write_text("")
        self.env = os.environ | {
            "MISE_TRUSTED_CONFIG_PATHS": str(self.root),
            "MISE_DATA_DIR": str(Path(self.temp.name) / "mise-data"),
            "MISE_STATE_DIR": str(Path(self.temp.name) / "mise-state"),
            "MISE_CACHE_DIR": str(Path(self.temp.name) / "mise-cache"),
            "MISE_GLOBAL_CONFIG_FILE": str(empty_config),
            "MISE_SYSTEM_CONFIG_FILE": str(empty_config),
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

    def test_tasks_preserve_caller_tool_precedence_over_the_system_profile(self):
        self.copy_project()
        tools = self.root / "fake-tools"
        tools.mkdir()
        nix = tools / "nix"
        nix.write_text(
            f"#!{shutil.which('bash')}\nset -euo pipefail\n"
            'if [[ "$1" == eval ]]; then echo x86_64-linux; else printf "%s\\n" "$PATH"; fi\n'
        )
        nix.chmod(0o755)
        system_bin = "/run/current-system/sw/bin"
        inherited = [p for p in self.env["PATH"].split(os.pathsep) if p != system_bin]
        self.env["PATH"] = os.pathsep.join([str(tools), *inherited, system_bin])
        for command in [("mise", "run"), (str(self.root / "bin/hey"),)]:
            with self.subTest(command=command):
                result = self.run_command(*command, "show")
                self.assertEqual(result.returncode, 0, result.stderr)
                paths = result.stdout.strip().split(os.pathsep)
                self.assertLess(paths.index(str(tools)), paths.index(system_bin))
                self.assertEqual(paths.count(system_bin), 1)

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
            ("pi:update", "version"),
            ("pi-update", "version"),
            ("xcode:setup", "app"),
            ("xcode-setup", "app"),
            ("unas", "mode"),
            ("unas:recover", "root"),
            ("unas-recover", "root"),
            ("u", "inputs"),
        ]:
            with self.subTest(task=task):
                result = self.run_command("mise", "run", task, "--help")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(parameter, result.stdout)
                self.assertIn("Parameters:", result.stdout)

    def test_pi_update_uses_selected_checkout_and_never_rebuilds_after_failure(self):
        self.copy_project()
        tools = self.root / "fake-tools"
        tools.mkdir()
        nix = tools / "nix"
        nix.write_text(
            f"#!{shutil.which('bash')}\nset -euo pipefail\n"
            'if [[ "$1" == eval ]]; then echo x86_64-linux; exit; fi\n'
            '[[ "$*" == "run $MISE_PROJECT_ROOT#pi.updater -- $MISE_PROJECT_ROOT/overlays/pi 1.5.0" ]] || exit 92\n'
            'exit "$TEST_UPDATE_EXIT"\n'
        )
        nix.chmod(0o755)
        rebuild = self.root / "mise-tasks/rebuild.nu"
        rebuild.write_text(
            f"#!{shutil.which('bash')}\nprintf 'rebuilt %s\\n' \"$MISE_PROJECT_ROOT\"\n"
        )
        self.env["PATH"] = f"{tools}:{self.env['PATH']}"
        self.env["FLAKE_DIR"] = "/wrong-checkout"
        for exit_code in (0, 23):
            with self.subTest(exit_code=exit_code):
                self.env["TEST_UPDATE_EXIT"] = str(exit_code)
                result = self.run_command("mise", "run", "pi-update", "1.5.0")
                self.assertEqual(result.returncode, exit_code, result.stderr)
                self.assertEqual(
                    result.stdout, f"rebuilt {self.root}\n" if exit_code == 0 else ""
                )

    @unittest.skipUnless(
        os.environ.get("PI_SELF_UPDATE_TEST_LAUNCHER"), "Nix-built Pi launcher required"
    )
    def test_packaged_pi_update_runs_real_guards_with_only_boundary_mocks(self):
        self.copy_project()
        # Nix's test harness patches shebangs. Restore the checkout's env lookup
        # while using an env executable that exists inside its sandbox.
        for name in ("pi/update.nu", "rebuild.nu"):
            task = self.root / "mise-tasks" / name
            task.write_text(
                f"#!{shutil.which('env')} -S nu --no-config-file\n"
                + task.read_text().split("\n", 1)[1]
            )
        tools = self.root / "fake-tools"
        tools.mkdir()
        log = self.root / "operations"
        wrappers = self.root / "host-wrappers"
        profile = self.root / "host-profile"
        wrappers.mkdir()
        profile.mkdir()
        self.env.update(
            PATH=str(tools),
            HOME=str(Path(self.temp.name) / "home"),
            GH_CONFIG_DIR=str(Path(self.temp.name) / "gh"),
            FLAKE_DIR=str(self.root),
            TEST_LOG=str(log),
            TEST_OVERRIDES=str(self.root / "caller-tools"),
            TEST_PRIVILEGED_LOG=str(self.root / "privileged-calls"),
            NIX_CONFIG="experimental-features = nix-command flakes",
        )
        for key in (
            "GH_TOKEN",
            "GITHUB_TOKEN",
            "GH_ENTERPRISE_TOKEN",
            "GITHUB_ENTERPRISE_TOKEN",
            "GH_HOST",
        ):
            self.env.pop(key, None)
        Path(self.env["HOME"]).mkdir()
        (Path(self.env["HOME"]) / ".config").mkdir()
        (Path(self.env["HOME"]) / ".config/dotfiles").symlink_to(self.root)
        self.env["GH_PROMPT_DISABLED"] = "1"
        bash = shutil.which("bash")

        def executable(name, body, directory=tools):
            path = directory / name
            path.write_text(f"#!{bash}\nset -euo pipefail\n" + body)
            path.chmod(0o755)
            return path

        activation = executable(
            "darwin-rebuild",
            'echo activation >> "$TEST_LOG"\nexit "$TEST_ACTIVATION_EXIT"\n',
            profile,
        )
        executable(
            "nixos-rebuild",
            activation.read_text().split("set -euo pipefail\n", 1)[1],
            profile,
        )
        executable("sudo", 'echo sudo >> "$TEST_PRIVILEGED_LOG"\nexec "$@"\n', wrappers)
        executable("sudo", 'echo unsafe-sudo >> "$TEST_LOG"\nexit 96\n', profile)
        executable("systemctl", 'echo post >> "$TEST_LOG"\nexit 0\n', profile)
        executable(
            "nix",
            """
case "$1" in
  eval) echo x86_64-linux ;;
  run)
    [[ "$*" == "run $MISE_PROJECT_ROOT#pi.updater -- $MISE_PROJECT_ROOT/overlays/pi 1.5.0" ]] || exit 94
    echo update >> "$TEST_LOG"; exit "$TEST_UPDATE_EXIT" ;;
  flake)
    echo archive >> "$TEST_LOG"
    if [[ "$TEST_OS" == macos ]]; then
      if [[ "$TEST_AUTH" == present ]]; then
        [[ "$NIX_CONFIG" == *'access-tokens = github.com=fixture-only-token'* ]] || exit 91
      else
        [[ "$NIX_CONFIG" == 'experimental-features = nix-command flakes' ]] || exit 92
        exit 41
      fi
    fi
    exit "$TEST_ARCHIVE_EXIT" ;;
  build)
    echo build >> "$TEST_LOG"
    mkdir -p "$MISE_PROJECT_ROOT/result/sw/bin"
    ln -s "$MISE_PROJECT_ROOT/host-profile/activation" "$MISE_PROJECT_ROOT/result/sw/bin/darwin-rebuild" ;;
  *) exit 93 ;;
esac
""",
        )
        (profile / "nix").symlink_to(tools / "nix")
        # Remap fixed host/privilege boundaries in the fixture, never on the host.
        # All guard and orchestration functions remain the production implementation.
        common = self.root / "scripts/nu/common.nu"
        source = (
            common.read_text()
            .replace("$nu.os-info.name", "$env.TEST_OS")
            .replace("/run/current-system/sw/bin", str(profile))
            .replace("/run/wrappers/bin", str(wrappers))
            .replace(
                "/nix/var/nix/profiles/default/bin", str(self.root / "nix-profile")
            )
            .replace("^/usr/bin/sudo", f'^"{wrappers / "sudo"}"')
        )
        common.write_text(source)
        (self.root / "flake.lock").write_text("{}\n")
        (self.root / "flake.nix").write_text("{}\n")
        git = shutil.which("git")
        subprocess.run([git, "init", "--quiet", str(self.root)], check=True)
        subprocess.run([git, "-C", str(self.root), "add", "."], check=True)
        launcher = self.root / "pi-self-update"
        launcher.write_text(
            Path(os.environ["PI_SELF_UPDATE_TEST_LAUNCHER"])
            .read_text()
            .replace("/run/current-system/sw/bin", str(profile))
            .replace("/run/wrappers/bin", str(wrappers))
        )
        launcher.chmod(0o755)
        for os_name in ("linux", "macos"):
            for case in (
                "success",
                "caller-tools",
                "dotfiles",
                "home",
                "invalid-lock",
                "conflict",
                "no-auth",
                "auth-failure",
                "update-failure",
                "archive-failure",
                "private-auth",
                "private-auth-failure",
                "private-auth-caller",
                "activation-failure",
                "fallback",
            ):
                if os_name == "macos" and case.startswith("private-auth"):
                    continue
                with self.subTest(os=os_name, case=case):
                    self.env.pop("FLAKE_DIR", None)
                    self.env.pop("DOTFILES", None)
                    if case == "dotfiles":
                        self.env["DOTFILES"] = str(self.root)
                    elif case != "home":
                        self.env["FLAKE_DIR"] = str(self.root)
                        self.env["DOTFILES"] = "/wrong-lower-priority-checkout"
                    self.env.update(
                        TEST_OS=os_name,
                        TEST_AUTH="absent"
                        if case in ("no-auth", "auth-failure")
                        else "present",
                        TEST_UPDATE_EXIT="23" if case == "update-failure" else "0",
                        TEST_ARCHIVE_EXIT="42"
                        if case in ("archive-failure", "private-auth-failure")
                        else "0",
                        TEST_ACTIVATION_EXIT="43"
                        if case == "activation-failure"
                        else "0",
                    )
                    self.env.pop("GH_TOKEN", None)
                    if case != "no-auth":
                        self.env["GH_TOKEN"] = "fixture-only-token"
                    if case == "auth-failure":
                        executable("gh", "exit 23\n")
                    else:
                        (tools / "gh").unlink(missing_ok=True)
                    if case.startswith("private-auth"):
                        executable(
                            "nix-private-github",
                            'echo "$1" >> "$TEST_PRIVILEGED_LOG"\nexec "$@"\n',
                            profile,
                        )
                    else:
                        (profile / "nix-private-github").unlink(missing_ok=True)
                    if case == "private-auth-caller":
                        executable(
                            "sudo",
                            'echo caller-sudo >> "$TEST_PRIVILEGED_LOG"\nexec "$@"\n',
                        )
                    else:
                        (tools / "sudo").unlink(missing_ok=True)
                    Path(self.env["TEST_PRIVILEGED_LOG"]).unlink(missing_ok=True)
                    for name in ("nu", "mise"):
                        if case == "caller-tools":
                            executable(
                                name,
                                f'echo {name} >> "$TEST_OVERRIDES"\n'
                                f'exec "{shutil.which(name)}" "$@"\n',
                            )
                        else:
                            (tools / name).unlink(missing_ok=True)
                    Path(self.env["TEST_OVERRIDES"]).unlink(missing_ok=True)
                    lock = (
                        "bad json\n"
                        if case == "invalid-lock"
                        else "<<<<<<< conflict\n"
                        if case == "conflict"
                        else "{}\n"
                    )
                    (self.root / "flake.lock").write_text(lock)
                    if case == "fallback":
                        activation.rename(profile / "activation")
                    log.unlink(missing_ok=True)
                    result = self.run_command(launcher, "1.5.0", cwd=self.temp.name)
                    if case == "fallback":
                        (profile / "activation").rename(activation)
                    operations = log.read_text().splitlines()
                    expected = ["update"]
                    if case not in ("invalid-lock", "conflict", "update-failure"):
                        expected.append("archive")
                        if case not in (
                            "archive-failure",
                            "private-auth-failure",
                        ) and not (
                            os_name == "macos" and case in ("no-auth", "auth-failure")
                        ):
                            if os_name == "macos" and case == "fallback":
                                expected.append("build")
                            expected.append("activation")
                            if os_name == "linux" and case != "activation-failure":
                                expected.append("post")
                    self.assertEqual(operations, expected, result.stderr)
                    success = case in (
                        "success",
                        "caller-tools",
                        "dotfiles",
                        "home",
                        "fallback",
                        "private-auth",
                        "private-auth-caller",
                    ) or (os_name == "linux" and case in ("no-auth", "auth-failure"))
                    self.assertEqual(result.returncode == 0, success, result.stderr)
                    if case == "invalid-lock":
                        self.assertIn("flake.lock is not valid JSON", result.stderr)
                    if case == "conflict":
                        self.assertIn(
                            "flake.lock contains git conflict markers", result.stderr
                        )
                    self.assertNotIn(
                        "fixture-only-token", result.stdout + result.stderr
                    )
                    if case.startswith("private-auth"):
                        self.assertEqual(
                            Path(self.env["TEST_PRIVILEGED_LOG"])
                            .read_text()
                            .splitlines(),
                            ["sudo", "nix"]
                            if case == "private-auth-failure"
                            else ["caller-sudo", "nix", "sudo", "nixos-rebuild"]
                            if case == "private-auth-caller"
                            else ["sudo", "nix", "sudo", "nixos-rebuild"],
                        )
                    if case == "caller-tools":
                        self.assertEqual(
                            set(
                                Path(self.env["TEST_OVERRIDES"])
                                .read_text()
                                .splitlines()
                            ),
                            {"nu", "mise"},
                        )

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
