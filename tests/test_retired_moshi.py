import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "modules/agents/retired-moshi/cleanup.py"
SPEC = importlib.util.spec_from_file_location("moshi_cleanup", SCRIPT)
cleanup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cleanup)


class RetiredMoshiTests(unittest.TestCase):
    def test_command_matching_preserves_unrelated_or_compound_commands(self):
        for command in (
            "echo moshi-hook",
            "moshi-hook status",
            "moshi-hook claude-hook && echo keep",
            "other-moshi-hook claude-hook",
            "'unterminated",
        ):
            with self.subTest(command=command):
                self.assertFalse(cleanup.is_moshi_command({"type": "command", "command": command}))

    def run_cleanup(self, home):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(home)],
            capture_output=True,
            text=True,
            check=True,
        )

    def test_generated_hooks_are_archived_and_cleanup_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            for relative in cleanup.HOOK_FILES:
                path = home / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(cleanup.GENERATED_MARKER + "\noriginal hook\n")
            self.run_cleanup(home)
            backups = list((home / ".local/state/dotfiles/retired-moshi").iterdir())
            self.assertEqual(len(backups), 1)
            for relative in cleanup.HOOK_FILES:
                self.assertFalse((home / relative).exists())
                self.assertEqual(
                    (backups[0] / relative).read_text(),
                    cleanup.GENERATED_MARKER + "\noriginal hook\n",
                )
            self.assertEqual(self.run_cleanup(home).stdout, "")
            self.assertEqual(len(list(backups[0].parent.iterdir())), 1)

    def test_preserves_custom_files_and_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            custom = home / cleanup.HOOK_FILES[0]
            custom.parent.mkdir(parents=True)
            custom.write_text("custom implementation\n")
            link = home / cleanup.HOOK_FILES[1]
            link.parent.mkdir(parents=True)
            link.symlink_to(custom)
            self.run_cleanup(home)
            self.assertEqual(custom.read_text(), "custom implementation\n")
            self.assertTrue(link.is_symlink())
            self.assertFalse((home / ".local/state/dotfiles/retired-moshi").exists())

    def test_removes_only_moshi_commands_preserving_other_settings_and_backups(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            keep = {"type": "command", "command": "echo moshi-hook"}
            moshi = {
                "type": "command",
                "command": "'/path with spaces/moshi-hook' claude-hook",
            }
            original = {
                "permissions": {"allow": ["Read"]},
                "hooks": {
                    "SessionStart": [{"matcher": "*", "hooks": [moshi, keep]}],
                    "Stop": [{"hooks": [moshi]}],
                    "Empty": [],
                },
            }
            for relative in (".claude/settings.json", ".codex/hooks.json"):
                path = home / relative
                path.parent.mkdir(parents=True)
                path.write_text(json.dumps(original))
                path.chmod(0o600)
            self.run_cleanup(home)
            backup = next((home / ".local/state/dotfiles/retired-moshi").iterdir())
            for relative in (".claude/settings.json", ".codex/hooks.json"):
                path = home / relative
                data = json.loads(path.read_text())
                self.assertEqual(data["permissions"], original["permissions"])
                self.assertEqual(data["hooks"]["SessionStart"], [{"matcher": "*", "hooks": [keep]}])
                self.assertNotIn("Stop", data["hooks"])
                self.assertEqual(data["hooks"]["Empty"], [])
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(json.loads((backup / relative).read_text()), original)
            self.assertEqual(self.run_cleanup(home).stdout, "")

    def test_retirement_is_wired_and_secret_is_not_provisioned(self):
        module = (SCRIPT.parent / "default.nix").read_text()
        self.assertIn("home.activation.retired-moshi-cleanup", module)
        self.assertIn('${./cleanup.py} "$HOME"', module)
        self.assertNotIn("mkIf", module)
        self.assertNotIn(
            '"moshi-hook-secrets-json.age"',
            (ROOT / "hosts/nuc/secrets/secrets.nix").read_text(),
        )
        self.assertFalse((ROOT / "hosts/nuc/secrets/moshi-hook-secrets-json.age").exists())


if __name__ == "__main__":
    unittest.main()
