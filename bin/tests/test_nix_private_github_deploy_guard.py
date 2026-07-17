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
            "GITHUB_NIX_TOKEN_FILE": str(self.token),
            "NIXOS_DEPLOY_LOCK_FILE": str(self.root / "deploy.lock"),
            "NIXOS_DEPLOY_OWNER_FILE": str(self.root / "deploy.owner"),
            "NIXOS_DEPLOY_REMOTE_MAIN": "main-sha",
            "COMMAND_MARKER": str(self.marker),
            "COMMAND_READY": str(self.ready),
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

    def test_rollback_takes_lock_without_worktree_metadata(self) -> None:
        result = self.run_wrapper(str(self.command), "--rollback", "switch")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
