"""Exercise sudo routing against a disposable sudo and Rex server boundary."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parent


class NativeSudoPromptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="hey sudo build ")
        cls.addClassCleanup(cls.build.cleanup)
        source = Path(cls.build.name)
        for path in SOURCE.iterdir():
            if path.suffix in (".bend", ".c", ".h"):
                target = source / path.name
                shutil.copy2(path, target)
                if path.suffix == ".bend":
                    text = target.read_text()
                    for prefix in ("/run/wrappers/bin", "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin"):
                        text = text.replace(prefix, str(source / "no-system-tools"))
                    text = text.replace('"/usr/bin/env"', json.dumps(shutil.which("env")))
                    target.write_text(text)
        (source / "sudo-driver.bend").write_text(
            'import Base\nimport ./sudo-prompt.bend as Sudo\n'
            'import ./resources.bend as Resources\nimport ./os.bend as OS\n'
            'def main() -> IO(Unit):\n'
            '  do IO<Unit>:\n'
            '    sudo : String <- OS.required_environment("HEY_TEST_SUDO")\n'
            '    Sudo.run_sudo_command(sudo, ["darwin-rebuild", "switch", "a b"], "fixture-only-token")\n'
            '    Resources.finish_task(0)\n'
        )
        subprocess.run(["bend", str(source / "sudo-driver.bend"), "-o", str(source / "generated.c")], check=True)
        cls.binary = source / "sudo-driver"
        subprocess.run(
            ["clang", "-O2", "-pthread", str(source / "launcher.c"), "-o", str(cls.binary), "-lm"], check=True
        )

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey sudo fixture ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.log = self.root / "commands.jsonl"
        self.state = self.root / "pane.json"
        for name in ("jq", "rm"):
            (self.tools / name).symlink_to(shutil.which(name))
        self.env = os.environ | {
            "PATH": str(self.tools),
            "HEY_TEST_SUDO": str(self.tools / "sudo"),
            "HEY_SUDO_LOG": str(self.log), "HEY_PANE_STATE": str(self.state),
            "REX_SESSION": "fixture-session", "REX_BLOCK": "fixture-anchor",
            "HEY_REX": "1", "HOME": str(self.root), "NIX_CONFIG": "original-config",
        }
        common = (
            "import json, os, pathlib, sys\n"
            "assert all('fixture-only-token' not in arg for arg in sys.argv)\n"
            "with open(os.environ['HEY_SUDO_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([pathlib.Path(sys.argv[0]).name, sys.argv[1:]]) + '\\n')\n"
        )
        self.executable(
            "sudo", common +
            "if sys.argv[1:] == ['-n', 'true']:\n"
            "    assert os.environ['NIX_CONFIG'] == 'original-config'\n"
            "    raise SystemExit(int(os.environ.get('HEY_CACHED', '1')))\n"
            "assert os.environ['NIX_CONFIG'] == 'fixture-only-token'\n"
            "raise SystemExit(int(os.environ.get('HEY_TASK_EXIT', '0')))\n"
        )
        self.executable(
            "rex", common +
            "assert 'fixture-only-token' not in os.environ.get('NIX_CONFIG', '')\n"
            "state = pathlib.Path(os.environ['HEY_PANE_STATE'])\n"
            "args = sys.argv[1:]\n"
            "alive = json.loads(state.read_text()) if state.exists() else False\n"
            "if args[0] == 'split':\n"
            "    state.write_text('true')\n"
            "    print(json.dumps({'block_ids': ['fixture-pane']}))\n"
            "    raise SystemExit(int(os.environ.get('HEY_TASK_EXIT', '0')))\n"
            "if args[0] == 'capture':\n"
            "    if os.environ.get('HEY_CLEAR_EARLY') == '1':\n"
            "        state.write_text('false')\n"
            "        raise SystemExit(1)\n"
            "    print('sudo task output')\n"
            "elif args[:2] == ['block', 'close']:\n"
            "    state.write_text('false')\n"
            "    raise SystemExit(0 if alive else 1)\n"
            "elif args[:2] == ['block', 'ls']:\n"
            "    print(json.dumps({'blocks': [{'block_id': 'fixture-pane'}] if alive else []}))\n"
            "else: raise SystemExit(92)\n"
        )

    def executable(self, name, body):
        path = self.tools / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def run_sudo(self):
        return subprocess.run(
            [self.binary], env=self.env, cwd=self.root,
            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15,
        )

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_cached_credentials_use_sudo_without_opening_a_pane(self):
        self.env["HEY_CACHED"] = "0"
        result = self.run_sudo()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [
            ["sudo", ["-n", "true"]], ["sudo", ["darwin-rebuild", "switch", "a b"]]
        ])
        self.assertFalse(self.state.exists())

    def test_explicit_opt_out_does_not_probe_or_open_rex(self):
        self.env["HEY_REX"] = "0"
        self.env["HEY_TASK_EXIT"] = "43"
        result = self.run_sudo()
        self.assertEqual(result.returncode, 43, result.stderr)
        self.assertEqual(self.commands(), [["sudo", ["darwin-rebuild", "switch", "a b"]]])

    def test_prompted_operation_preserves_status_captures_and_verifies_cleanup(self):
        for status in (0, 43):
            with self.subTest(status=status):
                self.log.unlink(missing_ok=True)
                self.env["HEY_TASK_EXIT"] = str(status)
                result = self.run_sudo()
                self.assertEqual(result.returncode, status, result.stderr)
                calls = self.commands()
                split = next(args for tool, args in calls if tool == "rex" and args[0] == "split")
                self.assertIn("fixture-session", split)
                self.assertIn("fixture-anchor", split)
                self.assertEqual(split[-3:], ["darwin-rebuild", "switch", "a b"])
                self.assertIn("sudo task output", result.stdout)
                self.assertFalse(json.loads(self.state.read_text()))
                self.assertEqual([args[0:2] for tool, args in calls if tool == "rex"][-2:], [["block", "close"], ["block", "ls"]])
                self.assertNotIn("fixture-only-token", result.stdout + result.stderr)

    def test_already_closed_owned_pane_is_not_closed_again_at_exit(self):
        self.env["HEY_CLEAR_EARLY"] = "1"
        result = self.run_sudo()
        self.assertEqual(result.returncode, 0, result.stderr)
        closes = [args for tool, args in self.commands() if tool == "rex" and args[:2] == ["block", "close"]]
        self.assertEqual(len(closes), 1)
        self.assertFalse(json.loads(self.state.read_text()))


if __name__ == "__main__":
    unittest.main()
