"""Exercise the report command without allowing real cleanup or model calls."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "config/mole/disk-reclaim-report.sh"


class MoleDiskReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.report = self.root / "reports"
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "MOLE_REPORT_DIR": str(self.report),
            "MOLE_REPORT_AMP_SETTINGS": str(ROOT / "config/mole/report-amp-settings.json"),
            "CAPTURE": str(self.root / "prompt.txt"),
        }
        self.command(
            "mole",
            'if [ "$1" = --version ]; then echo "Mole fixture"; exit; fi\n'
            '[ "$#" = 2 ] && [ "$2" = --dry-run ] || exit 90\n'
            'printf "\\033[32m%s candidate 7GB\\033[0m\\n" "$1"\n'
            'if [ "$1" = clean ]; then exit "${SCAN_EXIT:-0}"; fi\n',
        )
        self.command(
            "amp",
            'cat > "$CAPTURE"\n'
            'echo "Summary available"\n'
            'exit "${AMP_EXIT:-0}"\n',
        )
        self.command(
            "df",
            'echo "Filesystem 1024-blocks Used Available Capacity Mounted"\n'
            'echo "disk 1048576000 734003200 ${FREE_KIB:-52428800} 95% /"\n',
        )
        self.command(
            "du",
            'printf "94371840\\t/home/example/Library\\n"\n'
            'exit "${INVENTORY_EXIT:-0}"\n',
        )
        # Retain real timeout behavior across macOS and Linux tool names.
        timeout = shutil.which("timeout") or shutil.which("gtimeout")
        if timeout is None:
            self.skipTest("GNU timeout is required")
        (self.bin / "timeout").symlink_to(timeout)

    def command(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\nset -eu\n" + body)
        path.chmod(0o700)

    def run_report(self, **env):
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env={**self.env, **env},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_preview_only_and_private_readable_evidence(self):
        result = self.run_report()
        self.assertEqual(result.returncode, 0, result.stderr)
        scan = (self.report / "latest-scan.txt").read_text()
        self.assertIn("clean candidate 7GB", scan)
        self.assertIn("purge candidate 7GB", scan)
        self.assertNotIn("\x1b", scan)
        self.assertEqual((self.report / "latest.md").stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(self.report.glob(".scan.*")), [])

    def test_failures_replace_stale_report_and_keep_partial_evidence(self):
        self.report.mkdir()
        (self.report / "latest.md").write_text("Old successful report")
        result = self.run_report(SCAN_EXIT="124", AMP_EXIT="7")
        self.assertEqual(result.returncode, 1)
        report = (self.report / "latest.md").read_text()
        self.assertIn("Amp summary unavailable (exit 7)", report)
        self.assertIn("incomplete", report)
        self.assertNotIn("Old successful", report)
        scan = (self.report / "latest-scan.txt").read_text()
        self.assertIn("Scan exit status: 124", scan)
        self.assertIn("purge candidate 7GB", scan)

    def test_capacity_goal_uses_available_space_not_single_volume_used(self):
        # 1000 GiB capacity, 50 GiB available: need 350 GiB more free.
        result = self.run_report()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = (self.report / "latest.md").read_text()
        self.assertIn("Current occupied: 950.00 GiB of 1000.00 GiB (95.0%)", report)
        self.assertIn("Additional space required: 350.00 GiB", report)
        self.assertIn("94371840", (self.root / "prompt.txt").read_text())
        # 550 GiB occupied is already below 60%; no negative reclaim target.
        result = self.run_report(FREE_KIB="471859200", AMP_EXIT="7")
        self.assertEqual(result.returncode, 1)
        report = (self.report / "latest.md").read_text()
        self.assertIn("Additional space required: 0.00 GiB", report)
        self.assertIn("Amp summary unavailable", report)

    def test_incomplete_inventory_is_visible_even_when_amp_succeeds(self):
        result = self.run_report(INVENTORY_EXIT="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("incomplete", (self.report / "latest.md").read_text())
        self.assertIn(
            "Inventory exit status: 1",
            (self.report / "latest-scan.txt").read_text(),
        )

    def test_large_scan_is_bounded_for_amp_but_evidence_is_complete(self):
        self.command(
            "mole",
            'if [ "$1" = --version ]; then echo "Mole fixture"; exit; fi\n'
            'echo START-EVIDENCE\n'
            "head -c 70000 /dev/zero | tr '\\000' x\n"
            'echo END-EVIDENCE\n',
        )
        result = self.run_report()
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = (self.root / "prompt.txt").read_text()
        self.assertLess(len(prompt), 62000)
        self.assertIn("[SCAN TRUNCATED: middle omitted]", prompt)
        self.assertIn("START-EVIDENCE", prompt)
        self.assertIn("END-EVIDENCE", prompt)
        self.assertGreater((self.report / "latest-scan.txt").stat().st_size, 140000)


if __name__ == "__main__":
    unittest.main()
