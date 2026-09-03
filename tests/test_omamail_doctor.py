import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DOCTOR = (
    REPO_ROOT
    / "hosts"
    / "meshify"
    / "omarchy"
    / "local"
    / "bin"
    / "omamail-doctor"
)


@unittest.skipIf(sys.platform == "darwin", "secret-tool is Linux-only")
class OmamailDoctorTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.home = self.root / "home"
        self.config = self.home / ".config" / "omamail"
        self.bin = self.root / "bin"
        self.config.mkdir(parents=True)
        self.bin.mkdir()
        self.gmail = "person@example.invalid"
        self.client = "client.apps.example.invalid"
        (self.config / "credentials.json").write_text(
            json.dumps({"installed": {"client_id": self.client}}) + "\n"
        )
        secret_tool = self.bin / "secret-tool"
        secret_tool.write_text(
            "#!/usr/bin/env bash\n"
            "if [[ $1 == search ]]; then\n"
            "  cat <<'EOF'\n"
            "[/1]\n"
            "attribute.service = omamail\n"
            f"attribute.account = {self.gmail}\n"
            f"attribute.client-id = {self.client}\n"
            "attribute.grant = calendar-events-v1\n"
            "attribute.kind = refresh-token\n"
            "[/2]\n"
            "attribute.service = omamail\n"
            "attribute.account = imap:mail@example.invalid\n"
            "attribute.kind = imap-password\n"
            "EOF\n"
            "  exit 0\n"
            "fi\n"
            "cat >/dev/null\n"
            "[[ $1 == lookup && $* == *'kind imap-password'* ]]\n"
        )
        secret_tool.chmod(0o755)

    def write_accounts(self, accounts: list[dict[str, object]], active_id: str) -> None:
        (self.config / "accounts.json").write_text(
            json.dumps({"version": 1, "accounts": accounts, "activeId": active_id})
            + "\n"
        )
        (self.config / "accounts.json").chmod(0o600)

    def run_doctor(self, command: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["PATH"] = f"{self.bin}:{env['PATH']}"
        return subprocess.run(
            [DOCTOR, command, "--home", self.home],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

    def test_repair_replaces_blank_rows_without_printing_account_names(self) -> None:
        fastmail = {
            "id": "imap:mail@example.invalid",
            "email": "mail@example.invalid",
            "provider": "imap",
            "imap": {},
        }
        blank = {"id": "", "email": "", "provider": "imap", "imap": {}}
        self.write_accounts([fastmail, blank, blank], str(fastmail["id"]))

        before = self.run_doctor("check")
        repaired = self.run_doctor("repair")
        after = self.run_doctor("check")

        self.assertNotEqual(before.returncode, 0)
        self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)
        self.assertEqual(after.returncode, 0, after.stdout + after.stderr)
        accounts = json.loads((self.config / "accounts.json").read_text())
        self.assertEqual([entry["provider"] for entry in accounts["accounts"]], ["imap", "gmail"])
        self.assertEqual(stat.S_IMODE((self.config / "accounts.json").stat().st_mode), 0o600)
        combined = repaired.stdout + repaired.stderr + after.stdout + after.stderr
        self.assertNotIn(self.gmail, combined)
        self.assertNotIn(self.client, combined)
        backups = list((self.home / ".local" / "state" / "omamail-recovery").glob("*/accounts.json"))
        self.assertEqual(len(backups), 1)

    def test_check_accepts_consistent_gmail_state(self) -> None:
        self.write_accounts(
            [{"id": self.gmail, "email": self.gmail, "provider": "gmail"}],
            self.gmail,
        )

        result = self.run_doctor("check")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "omamail-doctor: ok (1 account(s))\n")


if __name__ == "__main__":
    unittest.main()
