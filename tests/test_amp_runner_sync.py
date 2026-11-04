"""Exercise runner registration through the CLI with a disposable Amp substitute."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class AmpRunnerSyncTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        for name in ("existing", "new project", "unmanaged"):
            (self.home / name).mkdir()
        self.state = self.home / "state.json"
        self.state.write_text(json.dumps(["~/existing", "~/unmanaged"]))
        self.config = self.home / "runner.json"
        self.config.write_text(
            json.dumps(
                {
                    "runnerId": "fixture-runner",
                    "directories": [
                        "~/existing",
                        "~/new project",
                        "~/new project",
                        "~/missing",
                    ],
                }
            )
        )
        fake = self.home / "amp"
        fake.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "state = Path(os.environ['HOME']) / 'state.json'\n"
            "args = sys.argv[1:]\n"
            "assert args[:2] == ['runner', 'dirs']\n"
            "assert args[3:5] == ['--runner-id', 'fixture-runner']\n"
            "if os.environ.get('FAIL_AMP') == args[2]:\n"
            "    sys.exit('runner unavailable')\n"
            "paths = json.loads(state.read_text())\n"
            "if args[2] == 'list':\n"
            "    print('Runner fixture-runner serves directories:')\n"
            "    remotes = json.loads(os.environ.get('AMP_REMOTES', '{}'))\n"
            "    for path in paths:\n"
            "        suffix = ' (' + remotes[path] + ')' if path in remotes else ''\n"
            "        print('  ' + path + suffix)\n"
            "elif args[2] == 'add':\n"
            "    paths.append(args[5])\n"
            "    state.write_text(json.dumps(paths))\n"
            "else: raise AssertionError(args)\n"
        )
        fake.chmod(0o755)
        self.env = {**os.environ, "HOME": str(self.home), "PATH": str(self.home)}

    def invoke(self, *args):
        return subprocess.run(
            [
                sys.executable,
                str(ROOT / "bin/amp-runner-sync"),
                "--config",
                str(self.config),
                *args,
            ],
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_preview_then_apply_preserves_unmanaged_and_is_idempotent(self):
        preview = self.invoke()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertIn(f"Would add: {self.home / 'new project'}", preview.stdout)
        self.assertIn(
            "3 configured, 1 already registered, 1 to add, 1 missing", preview.stdout
        )
        self.assertEqual(
            json.loads(self.state.read_text()), ["~/existing", "~/unmanaged"]
        )
        applied = self.invoke("--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        expected = ["~/existing", "~/unmanaged", str(self.home / "new project")]
        self.assertEqual(json.loads(self.state.read_text()), expected)
        repeated = self.invoke("--apply")
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertIn("0 added, 1 missing", repeated.stdout)
        self.assertEqual(json.loads(self.state.read_text()), expected)

    def test_parenthesized_registration_does_not_hide_distinct_bare_directory(self):
        registered = [
            "~/plain",
            "~/demo (archive)",
            "~/https (review)",
            "~/scp",
            "~/ssh",
            "~/local",
        ]
        for path in [*registered, "~/demo"]:
            (self.home / path[2:]).mkdir()
        self.state.write_text(json.dumps(registered))
        self.env["AMP_REMOTES"] = json.dumps(
            {
                "~/https (review)": "https://example.com/repo.git",
                "~/scp": "git@example.com:repo.git",
                "~/ssh": "ssh://git@example.com/repo.git",
                "~/local": "/some/local/repo/.",
            }
        )
        self.config.write_text(
            json.dumps(
                {"runnerId": "fixture-runner", "directories": [*registered, "~/demo"]}
            )
        )
        preview = self.invoke()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertEqual(
            [
                line
                for line in preview.stdout.splitlines()
                if line.startswith("Would add:")
            ],
            [f"Would add: {self.home / 'demo'}"],
        )
        applied = self.invoke("--apply")
        self.assertEqual(applied.returncode, 0, applied.stderr)
        expected = [*registered, str(self.home / "demo")]
        self.assertEqual(json.loads(self.state.read_text()), expected)
        repeated = self.invoke("--apply")
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertIn("7 already registered, 0 added, 0 missing", repeated.stdout)
        self.assertEqual(json.loads(self.state.read_text()), expected)

    def test_runner_errors_fail_without_success_summary(self):
        for operation in ("list", "add"):
            with self.subTest(operation=operation):
                self.env["FAIL_AMP"] = operation
                result = self.invoke("--apply")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("runner unavailable", result.stderr)
                self.assertNotIn("Existing registrations preserved", result.stdout)
                self.assertEqual(
                    json.loads(self.state.read_text()), ["~/existing", "~/unmanaged"]
                )


if __name__ == "__main__":
    unittest.main()
