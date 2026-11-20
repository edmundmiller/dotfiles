#!/usr/bin/env python3
"""Regression coverage for serialized, current-main NUC deployments."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


WRAPPER = Path(os.environ["NIX_PRIVATE_GITHUB"])


class NucDeployGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.token = self.root / "token"
        self.token.write_text("test-token\n", encoding="utf-8")
        self.marker = self.root / "ran"
        self.ready = self.root / "ready"
        self.command = self.root / "nixos-rebuild"
        bash = shutil.which("bash")
        self.assertIsNotNone(bash)
        self.git_bin = self.root / "git-bin"
        self.git_bin.mkdir()
        self.fake_git = self.git_bin / "git"
        self.fake_git.write_text(
            f"#!{bash}\n"
            "set -euo pipefail\n"
            'if [[ "${1:-}" == -C ]]; then shift 2; fi\n'
            'case "${1:-}" in\n'
            "  rev-parse) exit 1 ;;\n"
            "  init) exit 0 ;;\n"
            '  fetch) printf \'%s\\n\' "$*" >>"$FAKE_GIT_LOG"; exit "${FAKE_GIT_FETCH_STATUS:-0}" ;;\n'
            '  merge-base) printf \'%s\\n\' "$*" >>"$FAKE_GIT_LOG"; '
            'if [[ "${3:-}" == "${FAKE_ACTIVE_SHA:-}" ]]; then exit "${FAKE_ACTIVE_ANCESTOR_STATUS:-0}"; fi; '
            'exit "${FAKE_GIT_ANCESTOR_STATUS:-1}" ;;\n'
            "  ls-remote)\n"
            '    if [[ -n "${FAKE_GIT_REMOTE_MAIN:-}" ]]; then\n'
            '      printf \'%s\\trefs/heads/main\\n\' "$FAKE_GIT_REMOTE_MAIN"\n'
            "    fi\n"
            '    exit "${FAKE_GIT_LS_REMOTE_STATUS:-0}"\n'
            "    ;;\n"
            "  *) exit 2 ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        self.fake_git.chmod(0o755)
        version = self.git_bin / "nixos-version"
        version.write_text(f"#!{bash}\nprintf '%s\\n' \"${{FAKE_ACTIVE_REVISION}}\"\n")
        version.chmod(0o755)
        self.command.write_text(
            f"#!{bash}\n"
            "set -euo pipefail\n"
            "touch \"$COMMAND_READY\"\n"
            "if [[ \"${COMMAND_HOLD:-0}\" == 1 ]]; then\n"
            "  trap 'exit 143' TERM\n"
            "  while :; do sleep 0.05; done\n"
            "fi\n"
            "sleep \"${COMMAND_SLEEP:-0}\"\n"
            "printf '%s\\n' \"$*\" >>\"$COMMAND_MARKER\"\n",
            encoding="utf-8",
        )
        self.command.chmod(0o755)
        self.env = os.environ | {
            "PATH": f"{self.git_bin}{os.pathsep}{os.environ['PATH']}",
            "GITHUB_NIX_TOKEN_FILE": str(self.token),
            "NIXOS_DEPLOY_LOCK_FILE": str(self.root / "deploy.lock"),
            "NIXOS_DEPLOY_OWNER_FILE": str(self.root / "deploy.owner"),
            "NIXOS_DEPLOY_REMOTE_MAIN": "main-sha",
            "COMMAND_MARKER": str(self.marker),
            "COMMAND_READY": str(self.ready),
            "FAKE_GIT_LOG": str(self.root / "git.log"),
            "FAKE_ACTIVE_SHA": "d" * 40,
            "FAKE_ACTIVE_REVISION": f"dotfiles={'d' * 40};agents-workspace={'e' * 40}",
        }

    def run_wrapper(
        self,
        *args: str,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(WRAPPER), *args],
            env=self.env | (env or {}),
            text=True,
            capture_output=True,
            check=False,
        )

    @staticmethod
    def cleanup_process(process: subprocess.Popen[str]) -> None:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        if process.stdout is not None:
            process.stdout.close()
        if process.stderr is not None:
            process.stderr.close()

    @staticmethod
    def source_args(base: str = "main-sha") -> list[str]:
        return [
            "--nuc-deploy-source-head=topic-sha",
            f"--nuc-deploy-source-base={base}",
            "--nuc-deploy-source-owner=test-owner",
        ]

    def test_ha_preserving_switch_rejects_changed_closure_and_dependency_restart(self) -> None:
        bash = shutil.which("bash")
        real_readlink = shutil.which("readlink")
        old = self.root / "active"
        target = self.root / "target"
        for root in (old, target):
            unit = root / "etc/systemd/system/home-assistant.service"
            unit.parent.mkdir(parents=True)
            unit.write_text("[Service]\nExecStart=/same/ha\n")
        (target / "bin").mkdir()
        plan = target / "bin/switch-to-configuration"
        plan.write_text(f"#!{bash}\nprintf '%s\\n' \"${{FAKE_ACTIVATION_PLAN:-unchanged}}\"\n")
        plan.chmod(0o755)
        commands = {
            "readlink": f'if [[ "$*" == "-f /run/current-system" ]]; then echo "{old}"; else exec "{real_readlink}" "$@"; fi',
            "systemctl": 'if [[ "$1" == is-active ]]; then exit 0; fi; if [[ "$*" == *NeedDaemonReload* ]]; then echo no; else echo MainPID=123; echo ActiveEnterTimestampMonotonic=456; fi',
            "nix": f'if flock -n "$NIXOS_DEPLOY_LOCK_FILE" true; then exit 91; fi; echo "{target}"',
        }
        for name, body in commands.items():
            command = self.git_bin / name
            command.write_text(f"#!{bash}\nset -eu\n{body}\n")
            command.chmod(0o755)
        sha = "a" * 40
        args = [f"--nuc-deploy-expected-main={sha}", "--nuc-deploy-preserve-home-assistant",
                *self.source_args(), str(self.command), "switch", "--flake", f"github:edmundmiller/dotfiles/{sha}#nuc"]
        # The packaged application prepends coreutils to PATH. Export shell
        # boundary stubs so the test never inspects the build host's generation.
        env = {"FAKE_GIT_REMOTE_MAIN": sha, "NIXOS_DEPLOY_GIT": str(self.fake_git)} | {
            f"BASH_FUNC_{name}%%": f'() {{ "{self.git_bin / name}" "$@"; }}'
            for name in commands
        }
        result = self.run_wrapper(*args, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.exists())
        self.assertIn("ha_continuity=verified_same_pid_and_start", result.stdout)
        self.marker.unlink()
        target_unit = target / "etc/systemd/system/home-assistant.service"
        target_unit.write_text("[Service]\nExecStart=/different/ha\n")
        result = self.run_wrapper(*args, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protected unit home-assistant.service would change", result.stderr)
        self.assertFalse(self.marker.exists())
        target_unit.write_text((old / "etc/systemd/system/home-assistant.service").read_text())
        alert_unit = target_unit.with_name("gatus-notion.service")
        alert_unit.write_text("[Service]\nExecStart=/unrelated/new/receiver\n")
        result = self.run_wrapper(*args, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protected unit gatus-notion.service would change", result.stderr)
        self.assertFalse(self.marker.exists())
        alert_unit.unlink()
        result = self.run_wrapper(*args, env=env | {"FAKE_ACTIVATION_PLAN": "would restart postgresql.service"})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("may interrupt HA", result.stderr)
        self.assertFalse(self.marker.exists())

    def test_current_main_snapshot_runs(self) -> None:
        result = self.run_wrapper(*self.source_args(), str(self.command), "switch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.exists())

    def test_stale_snapshot_is_rejected_before_activation(self) -> None:
        result = self.run_wrapper(
            *self.source_args(base="stale-sha"), str(self.command), "switch"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale NUC deployment snapshot", result.stderr)
        self.assertFalse(self.marker.exists())

    def test_explicit_stale_override_runs(self) -> None:
        result = self.run_wrapper(
            *self.source_args(base="stale-sha"),
            "--nuc-deploy-allow-stale",
            str(self.command),
            "switch",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("stale override", result.stderr)

    def test_concurrent_mutation_reports_lock_owner(self) -> None:
        first = subprocess.Popen(
            [str(WRAPPER), *self.source_args(), str(self.command), "switch"],
            env=self.env | {"COMMAND_SLEEP": "3"},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(self.cleanup_process, first)
        for _ in range(50):
            if self.ready.exists():
                break
            time.sleep(0.05)
        self.assertTrue(self.ready.exists())

        second = self.run_wrapper(*self.source_args(), str(self.command), "test")
        self.assertNotEqual(second.returncode, 0)
        self.assertIn("NUC deployment lock is held", second.stderr)
        self.assertIn("test-owner", second.stderr)
        first.wait(timeout=5)

    def test_interrupted_deploy_releases_lock(self) -> None:
        first = subprocess.Popen(
            [str(WRAPPER), *self.source_args(), str(self.command), "switch"],
            env=self.env | {"COMMAND_HOLD": "1"},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(self.cleanup_process, first)
        for _ in range(50):
            if self.ready.exists():
                break
            time.sleep(0.05)
        self.assertTrue(self.ready.exists())
        first.terminate()
        first.wait(timeout=5)
        self.ready.unlink(missing_ok=True)

        second = self.run_wrapper(*self.source_args(), str(self.command), "switch")
        self.assertEqual(second.returncode, 0, second.stderr)

    def test_build_remains_parallel_and_needs_no_source_metadata(self) -> None:
        result = self.run_wrapper(str(self.command), "build")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "deploy.lock").exists())

    def test_remote_flake_mutation_needs_no_worktree_metadata(self) -> None:
        result = self.run_wrapper(
            str(self.command), "switch", "--flake", "github:owner/repo#nuc"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_dotfiles_remote_flake_is_pinned_to_current_main(self) -> None:
        remote_main = "a" * 40
        result = self.run_wrapper(
            str(self.command),
            "switch",
            "--refresh",
            "--flake",
            "github:edmundmiller/dotfiles#nuc",
            env={
                "FAKE_GIT_REMOTE_MAIN": remote_main,
                "NIXOS_DEPLOY_GIT": str(self.fake_git),
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = self.marker.read_text(encoding="utf-8")
        self.assertIn(
            f"github:edmundmiller/dotfiles/{remote_main}#nuc",
            invocation,
        )
        self.assertNotIn("github:edmundmiller/dotfiles#nuc", invocation)

    def test_dotfiles_remote_flake_equals_form_is_pinned(self) -> None:
        remote_main = "b" * 40
        result = self.run_wrapper(
            str(self.command),
            "switch",
            "--flake=github:edmundmiller/dotfiles#nuc",
            env={
                "FAKE_GIT_REMOTE_MAIN": remote_main,
                "NIXOS_DEPLOY_GIT": str(self.fake_git),
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = self.marker.read_text(encoding="utf-8")
        self.assertIn(
            f"--flake=github:edmundmiller/dotfiles/{remote_main}#nuc",
            invocation,
        )

    def test_dotfiles_remote_flake_rejects_non_commit_remote_main(self) -> None:
        result = self.run_wrapper(
            str(self.command),
            "switch",
            "--flake",
            "github:edmundmiller/dotfiles#nuc",
            env={
                "FAKE_GIT_REMOTE_MAIN": "main-sha",
                "NIXOS_DEPLOY_GIT": str(self.fake_git),
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("origin/main is not a commit SHA", result.stderr)
        self.assertFalse(self.marker.exists())

    def test_dotfiles_remote_flake_ignores_stale_remote_main_override(self) -> None:
        stale_main = "c" * 40
        current_main = "d" * 40
        result = self.run_wrapper(
            str(self.command),
            "switch",
            "--flake",
            "github:edmundmiller/dotfiles#nuc",
            env={
                "FAKE_GIT_REMOTE_MAIN": current_main,
                "NIXOS_DEPLOY_GIT": str(self.fake_git),
                "NIXOS_DEPLOY_REMOTE_MAIN": stale_main,
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        invocation = self.marker.read_text(encoding="utf-8")
        self.assertIn(
            f"github:edmundmiller/dotfiles/{current_main}#nuc",
            invocation,
        )
        self.assertNotIn(stale_main, invocation)

    def test_dotfiles_remote_flake_rejects_failed_remote_lookup(self) -> None:
        result = self.run_wrapper(
            str(self.command),
            "switch",
            "--flake",
            "github:edmundmiller/dotfiles#nuc",
            env={
                "FAKE_GIT_LS_REMOTE_STATUS": "1",
                "FAKE_GIT_REMOTE_MAIN": "e" * 40,
                "NIXOS_DEPLOY_GIT": str(self.fake_git),
                "NIXOS_DEPLOY_REMOTE_MAIN": "",
            },
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("could not resolve current dotfiles origin/main", result.stderr)
        self.assertFalse(self.marker.exists())

    def test_approved_revision_requires_live_main_even_with_stale_override(self) -> None:
        approved = "a" * 40
        for current, lookup_status, allowed in [
            (approved, "0", True),
            ("b" * 40, "0", False),
            (approved, "1", False),
            ("not-a-sha", "0", False),
        ]:
            with self.subTest(current=current, lookup_status=lookup_status):
                self.marker.unlink(missing_ok=True)
                result = self.run_wrapper(
                    f"--nuc-deploy-expected-main={approved}",
                    "--nuc-deploy-allow-stale",
                    str(self.command),
                    "switch",
                    "--flake",
                    f"github:edmundmiller/dotfiles/{approved}#nuc",
                    env={
                        "FAKE_GIT_REMOTE_MAIN": current,
                        "FAKE_GIT_LS_REMOTE_STATUS": lookup_status,
                        "NIXOS_DEPLOY_GIT": str(self.fake_git),
                        "NIXOS_DEPLOY_REMOTE_MAIN": approved,
                    },
                )
                self.assertEqual(result.returncode == 0, allowed, result.stderr)
                self.assertEqual(self.marker.exists(), allowed)
                if allowed:
                    self.assertIn(
                        f"github:edmundmiller/dotfiles/{approved}#nuc",
                        self.marker.read_text(),
                    )

    def test_published_revision_may_trail_live_main_but_must_be_reachable(self) -> None:
        approved, newer = "a" * 40, "b" * 40
        for current, fetch, ancestor, allowed in [
            (approved, "0", "1", True),  # Equal to main needs no history.
            (newer, "0", "0", True),  # Main advanced past a green commit.
            (newer, "0", "1", False),  # Unpublished or force-pushed away.
            (newer, "128", "0", False),  # History unavailable fails closed.
            ("not-a-sha", "0", "0", False),
        ]:
            with self.subTest(current=current, fetch=fetch, ancestor=ancestor):
                self.marker.unlink(missing_ok=True)
                (self.root / "git.log").unlink(missing_ok=True)
                result = self.run_wrapper(
                    f"--nuc-deploy-published={approved}",
                    "--nuc-deploy-allow-stale",
                    str(self.command), "switch", "--flake",
                    f"github:edmundmiller/dotfiles/{approved}#nuc",
                    env={
                        "FAKE_GIT_REMOTE_MAIN": current,
                        "FAKE_GIT_FETCH_STATUS": fetch,
                        "FAKE_GIT_ANCESTOR_STATUS": ancestor,
                        "NIXOS_DEPLOY_GIT": str(self.fake_git),
                        "NIXOS_DEPLOY_REMOTE_MAIN": approved,
                    },
                )
                self.assertEqual(result.returncode == 0, allowed, result.stderr)
                self.assertEqual(self.marker.exists(), allowed)
                if current == newer and fetch == "0":
                    self.assertIn(
                        f"merge-base --is-ancestor {approved} {newer}",
                        (self.root / "git.log").read_text(),
                    )

    def test_published_revision_keeps_exact_flake_binding(self) -> None:
        approved = "a" * 40
        for args in [
            [f"--nuc-deploy-published={approved}", str(self.command), "switch",
             "--flake", "github:edmundmiller/dotfiles/" + "b" * 40 + "#nuc"],
            [f"--nuc-deploy-published={approved}", str(self.command), "--rollback", "switch"],
            [f"--nuc-deploy-published={approved}", f"--nuc-deploy-expected-main={approved}",
             str(self.command), "switch", "--flake",
             f"github:edmundmiller/dotfiles/{approved}#nuc"],
            ["--nuc-deploy-published=main", str(self.command), "switch"],
        ]:
            with self.subTest(args=args):
                result = self.run_wrapper(
                    *args, env={"FAKE_GIT_REMOTE_MAIN": approved,
                                "NIXOS_DEPLOY_GIT": str(self.fake_git)},
                )
                self.assertEqual(result.returncode, 64, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_published_revision_rechecks_active_generation_under_lock(self) -> None:
        approved = "a" * 40
        for revision, ancestor, allowed in [
            (f"dotfiles={'d' * 40};agents-workspace={'e' * 40}", "0", True),
            (f"dotfiles={'d' * 40};agents-workspace={'e' * 40}", "1", False),
            ("unknown-generation", "0", False),
        ]:
            with self.subTest(revision=revision, ancestor=ancestor):
                self.marker.unlink(missing_ok=True)
                result = self.run_wrapper(
                    f"--nuc-deploy-published={approved}", str(self.command), "switch", "--flake",
                    f"github:edmundmiller/dotfiles/{approved}#nuc",
                    env={"FAKE_GIT_REMOTE_MAIN": approved,
                         "FAKE_ACTIVE_REVISION": revision,
                         "FAKE_ACTIVE_ANCESTOR_STATUS": ancestor,
                         "NIXOS_DEPLOY_GIT": str(self.fake_git)},
                )
                self.assertEqual(result.returncode == 0, allowed, result.stderr)
                self.assertEqual(self.marker.exists(), allowed)

    def test_approved_revision_rejects_branch_names_before_activation(self) -> None:
        result = self.run_wrapper(
            "--nuc-deploy-expected-main=main", str(self.command), "switch"
        )
        self.assertEqual(result.returncode, 64)
        self.assertFalse(self.marker.exists())

    def test_approved_revision_cannot_build_a_different_source(self) -> None:
        approved = "a" * 40
        for flake in [
            "github:edmundmiller/dotfiles/" + "b" * 40 + "#nuc",
            "github:edmundmiller/dotfiles#nuc",
            ".#nuc",
            f"github:edmundmiller/dotfiles/{approved}#other-host",
        ]:
            with self.subTest(flake=flake):
                result = self.run_wrapper(
                    f"--nuc-deploy-expected-main={approved}",
                    str(self.command), "switch", "--flake", flake,
                    env={"FAKE_GIT_REMOTE_MAIN": approved,
                         "NIXOS_DEPLOY_GIT": str(self.fake_git)},
                )
                self.assertEqual(result.returncode, 64, result.stderr)
                self.assertFalse(self.marker.exists())

    def test_rollback_takes_lock_without_worktree_metadata(self) -> None:
        result = self.run_wrapper(str(self.command), "--rollback", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
