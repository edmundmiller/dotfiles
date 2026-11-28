"""Exercise Mole's interpreter handoff at Bash's actual startup boundary."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[1] / "config/mole/bash-env.sh"


class MoleBashStartupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.capture = self.root / "arguments"
        self.body = self.root / "body"
        interpreter = self.root / "interpreter"
        interpreter.write_text('#!/bin/sh\nprintf "%s\\0" "$@" > "$CAPTURE"\n')
        interpreter.chmod(0o700)
        self.env = {
            **os.environ,
            "BASH_ENV": str(HOOK),
            "MOLE_BASH_BIN": str(interpreter),
            "CAPTURE": str(self.capture),
            "BODY": str(self.body),
        }

    def run_bash(self, script, *args):
        return subprocess.run(
            [
                "/bin/bash",
                "-c",
                'printf "%s" "${BASH_VERSINFO[0]}" > "$BODY"; trap -p DEBUG',
                script,
                *args,
            ],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=5,
        )

    def test_mole_entrypoints_and_children_handoff_before_running(self):
        version = subprocess.check_output(
            ["/bin/bash", "-c", 'printf "%s" "${BASH_VERSINFO[0]}"'], text=True
        )
        if version != "3":
            self.skipTest("Apple Bash 3.2 is required to exercise the handoff")
        args = ["clean", "--dry-run", "two words", "line\nbreak"]
        for script in [
            "/opt/homebrew/bin/mo",
            "/opt/homebrew/bin/mole",
            "/opt/homebrew/Cellar/mole/1.65.0/libexec/bin/clean.sh",
            "/opt/homebrew/opt/mole/libexec/bin/purge.sh",
        ]:
            with self.subTest(script=script):
                result = self.run_bash(script, *args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.body.exists())
                self.assertEqual(
                    self.capture.read_bytes().split(b"\0"),
                    [value.encode() for value in [script, *args]] + [b""],
                )

    def test_unrelated_scripts_keep_their_interpreter_and_no_trap(self):
        result = self.run_bash("/opt/homebrew/bin/molecule")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.body.exists())
        self.assertFalse(self.capture.exists())
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
