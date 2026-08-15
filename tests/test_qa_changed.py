#!/usr/bin/env python3
"""Regression coverage for packages/pi-packages changed-file checks."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


QA_CHANGED = Path(__file__).parents[1] / "bin" / "qa-changed"


class QaChangedTest(unittest.TestCase):
    def test_tests_only_diff_runs_integration_tests(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "bin").mkdir()
            shutil.copy2(QA_CHANGED, root / "bin" / "qa-changed")
            tests = root / "packages" / "pi-packages" / "tests"
            tests.mkdir(parents=True)
            test_file = tests / "example.test.ts"
            test_file.write_text("before\n", encoding="utf-8")

            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Test User"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=root, check=True)
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "base"], cwd=root, check=True)
            test_file.write_text("after\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "test change"], cwd=root, check=True)

            fake_bin = root / "fake-bin"
            fake_bin.mkdir()
            calls = root / "bun-calls"
            bun = fake_bin / "bun"
            bun.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >>"$BUN_CALLS"\n', encoding="utf-8")
            bun.chmod(0o755)

            result = subprocess.run(
                ["/bin/bash", str(root / "bin" / "qa-changed"), "--base-ref", "HEAD~1"],
                cwd=root,
                env=os.environ | {"PATH": f"{fake_bin}:{os.environ['PATH']}", "BUN_CALLS": str(calls)},
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("running packages/pi-packages integration tests", result.stdout)
            self.assertIn("run --silent test:integration", calls.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
