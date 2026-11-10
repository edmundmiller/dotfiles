"""Keep snapshot pruning scoped to owned revision directories and live leases."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

PRUNER = Path(os.environ.get("HEY_TEST_NUC_PRUNER", Path(__file__).resolve().parents[2] / "bin/prune-nuc-deploy-snapshots"))


class NucSnapshotPruningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hey snapshot pruning ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "snapshots"
        self.root.mkdir()
        self.tools = self.base / "tools"
        self.tools.mkdir()
        self.log = self.base / "units.jsonl"
        systemctl = self.tools / "systemctl"
        systemctl.write_text(
            f"#!{sys.executable}\nimport json, os, sys\n"
            "args = sys.argv[1:]\nassert args[:3] == ['--user', 'is-active', '--quiet']\n"
            "with open(os.environ['HEY_PRUNE_LOG'], 'a') as log: log.write(json.dumps(args[-1]) + '\\n')\n"
            "statuses = json.loads(os.environ['HEY_PRUNE_STATUSES'])\n"
            "raise SystemExit(statuses.get(args[-1], 3))\n")
        systemctl.chmod(0o755)
        self.env = os.environ | {"PATH": str(self.tools) + os.pathsep + os.environ["PATH"],
                                 "HEY_PRUNE_LOG": str(self.log), "HEY_PRUNE_STATUSES": "{}"}
        self.now = int(time.time())

    def snapshot(self, number, owner=None, stale=False, user="tester"):
        identifier = str(uuid.UUID(int=number))
        path = self.root / f"dotfiles-worktree-{user}-{'1' * 40}-clean-{identifier}"
        path.mkdir()
        (path / "source").write_text("snapshot bytes")
        if owner is not None:
            marker = path / ".nuc-deploy-active"
            marker.write_text(owner)
            marker_time = self.now - 90000 if stale else self.now
            os.utime(marker, (marker_time, marker_time))
        directory_time = self.now - 1000 + number
        os.utime(path, (directory_time, directory_time))
        return path

    def prune(self, keep=2, user="tester"):
        return subprocess.run([shutil.which("bash"), str(PRUNER), str(self.root), user, str(keep)],
                              env=self.env, cwd=self.base, capture_output=True, text=True, timeout=10)

    def test_retention_keeps_newest_completed_snapshots_without_touching_active_or_unrelated_data(self):
        snapshots = [self.snapshot(number) for number in range(1, 7)]
        active = self.snapshot(7, owner="active")
        other_user = self.snapshot(8, user="someone-else")
        legacy = self.root / "dotfiles-worktree-tester-legacy"
        legacy.mkdir()
        result = self.prune()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([path.exists() for path in snapshots], [False, False, False, False, True, True])
        self.assertTrue(active.exists())
        self.assertTrue(other_user.exists())
        self.assertTrue(legacy.exists())
        (active / ".nuc-deploy-active").unlink()
        completed = self.prune()
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertFalse(snapshots[-2].exists())
        self.assertTrue(snapshots[-1].exists())
        self.assertTrue(active.exists())

    def test_stale_service_leases_are_bound_to_the_snapshots_own_unit(self):
        units = {number: "nuc-validation-" + str(uuid.UUID(int=number)) + ".service" for number in range(1, 5)}
        live = self.snapshot(1, owner="systemd-user-unit=" + units[1] + "\n", stale=True)
        orphan = self.snapshot(2, owner="systemd-user-unit=" + units[2] + "\n", stale=True)
        mismatched = self.snapshot(3, owner="systemd-user-unit=" + units[4] + "\n", stale=True)
        self.env["HEY_PRUNE_STATUSES"] = json.dumps({units[1]: 0, units[2]: 3, units[4]: 0})
        result = self.prune(keep=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((live / ".nuc-deploy-active").exists())
        self.assertFalse(orphan.exists())
        self.assertFalse(mismatched.exists())
        queried = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertIn(units[1], queried)
        self.assertIn(units[2], queried)
        self.assertNotIn(units[4], queried)

    def test_unknown_service_state_keeps_a_stale_snapshot_instead_of_guessing_it_is_unused(self):
        unit = "nuc-validation-" + str(uuid.UUID(int=1)) + ".service"
        path = self.snapshot(1, owner="systemd-user-unit=" + unit + "\n", stale=True)
        self.env["HEY_PRUNE_STATUSES"] = json.dumps({unit: 1})
        result = self.prune(keep=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((path / ".nuc-deploy-active").exists())
        self.assertIn("retaining", result.stderr)

    def test_an_abandoned_ordinary_lease_can_expire_without_following_directory_symlinks(self):
        stale = self.snapshot(1, owner="active", stale=True)
        outside = self.base / "unrelated directory"
        outside.mkdir()
        sentinel = outside / "keep.txt"
        sentinel.write_text("unrelated data")
        linked = self.root / f"dotfiles-worktree-tester-{'1' * 40}-clean-{uuid.UUID(int=2)}"
        linked.symlink_to(outside, target_is_directory=True)
        result = self.prune(keep=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(stale.exists())
        self.assertTrue(linked.is_symlink())
        self.assertEqual(sentinel.read_text(), "unrelated data")

    def test_invalid_owner_or_retention_cannot_remove_fixture_snapshots(self):
        path = self.snapshot(1)
        for keep, user in (("invalid", "tester"), (0, "../escape")):
            with self.subTest(keep=keep, user=user):
                result = self.prune(keep=keep, user=user)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertTrue(path.exists())


if __name__ == "__main__":
    unittest.main()
