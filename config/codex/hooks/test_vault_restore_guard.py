import json
import subprocess
import sys
import unittest
from pathlib import Path


GUARD = Path(__file__).with_name("vault_restore_guard.py")
VAULT = Path.home() / "obsidian-vault"


def run_guard(command, cwd=VAULT):
    payload = {
        "cwd": str(cwd),
        "tool_name": "Bash",
        "tool_input": {"command": command},
    }
    return subprocess.run(
        [sys.executable, GUARD],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        check=False,
    )


class VaultRestoreGuardTest(unittest.TestCase):
    def test_protects_openwiki_output_without_blocking_targeted_restore(self):
        historical_cleanup = '''python3 - <<'PY'
restoredTracked = [p for p in tracked if p.startswith("04_Resources/")]
subprocess.run(["git", "restore", "--worktree", "--source=HEAD", "--", *restoredTracked], check=True)
PY'''
        destructive_commands = [
            historical_cleanup,
            "git restore --worktree --source=HEAD -- 04_Resources/sources/x.md",
            "git restore --worktree --source=HEAD -- .",
        ]

        for command in destructive_commands:
            with self.subTest(command=command):
                result = run_guard(command)
                self.assertEqual(result.returncode, 0, result.stderr)
                decision = json.loads(result.stdout)
                self.assertEqual(
                    decision["hookSpecificOutput"]["permissionDecision"], "deny"
                )

        allowed = run_guard("git restore --worktree --source=HEAD -- 07_Metadata/report.md")
        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        self.assertEqual(allowed.stdout, "")

        outside_vault = run_guard(
            "git restore --worktree --source=HEAD -- 04_Resources/sources/x.md",
            cwd=Path.home() / ".config" / "dotfiles",
        )
        self.assertEqual(outside_vault.returncode, 0, outside_vault.stderr)
        self.assertEqual(outside_vault.stdout, "")


if __name__ == "__main__":
    unittest.main()
