"""Deletion boundaries and real rsync checksum checks for approved reclamation."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/reclaim-mac-development.py"
SPEC = importlib.util.spec_from_file_location("reclaim_mac", SCRIPT)
RECLAIM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECLAIM)


class ReclaimMacDevelopmentTests(unittest.TestCase):
    def test_cache_selection_preserves_models_whitelist_and_open_files(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory).resolve()
            (home / ".config/mole").mkdir(parents=True)
            (home / ".config/mole/whitelist").write_text("~/.cache/uv/*\n")
            for name in ["CocoaPods", "huggingface", "net.imput.helium"]:
                (home / "Library/Caches" / name).mkdir(parents=True)
            (home / ".cache/uv").mkdir(parents=True)
            with patch.object(
                RECLAIM.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(
                    [],
                    0,
                    stdout=(
                        f"n{home}/Library/Caches\n"
                        f"n{home}/Library/Caches/net.imput.helium/active\n"
                    ),
                ),
            ):
                self.assertEqual(
                    RECLAIM.reviewed_cleanup_targets(home, "caches", None),
                    [home / "Library/Caches/CocoaPods"],
                )

    def test_reviewed_artifacts_preserve_tracked_open_and_protected_data(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory).resolve()
            (home / ".config/mole").mkdir(parents=True)
            (home / ".config/mole/whitelist").write_text("~/protected/*\n")
            subprocess.run(["git", "init", "-q", str(home)], check=True)
            (home / ".gitignore").write_text("node_modules/\n.venv/\n")
            candidates = []
            for name in [
                "disposable/node_modules",
                "tracked/node_modules",
                "open/node_modules",
                "protected/node_modules",
                "active/.venv",
            ]:
                path = home / name
                path.mkdir(parents=True)
                (path / "data").write_text("valuable")
                candidates.append(path)
            subprocess.run(
                ["git", "-C", str(home), "add", "-f", "tracked/node_modules/data"],
                check=True,
            )
            manifest = home / "manifest"
            manifest.write_text("\n".join(map(str, candidates)))
            real_run = subprocess.run

            def with_open_files(command, **kwargs):
                if command[0] == "lsof":
                    return subprocess.CompletedProcess(
                        command, 0, stdout=f"n{home}/open/node_modules/data\n"
                    )
                return real_run(command, **kwargs)

            with patch.object(RECLAIM.subprocess, "run", side_effect=with_open_files):
                targets = RECLAIM.reviewed_cleanup_targets(home, "artifacts", manifest)
            self.assertEqual(targets, [home / "disposable/node_modules"])
            for path in candidates:
                self.assertEqual((path / "data").read_text(), "valuable")

    def test_mole_cache_preview_busy_and_apply(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory).resolve()
            cache = home / ".cache/mole"
            cache.mkdir(parents=True)
            (cache / "temporary").write_text("cache")
            other = home / ".cache/other"
            other.write_text("keep")
            for arguments, process_status, deleted in [
                ([], 1, False),
                (["--apply"], 0, False),
                (["--apply"], 1, True),
            ]:
                with (
                    patch.object(Path, "home", return_value=home),
                    patch.object(RECLAIM.platform, "system", return_value="Darwin"),
                    patch.object(
                        RECLAIM.subprocess,
                        "run",
                        return_value=subprocess.CompletedProcess([], process_status),
                    ),
                    patch.object(sys, "argv", [str(SCRIPT), "mole-cache", *arguments]),
                ):
                    if process_status == 0:
                        with self.assertRaises(SystemExit):
                            RECLAIM.main()
                    else:
                        RECLAIM.main()
                self.assertEqual(cache.exists(), not deleted)
                self.assertEqual(other.read_text(), "keep")

    def test_xcode_removes_only_explicit_targets(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory).resolve()
            xcode = home / "Library/Developer/Xcode"
            for name in [
                "DerivedData",
                "iOS DeviceSupport/old",
                "iOS DeviceSupport/new",
                "UserData",
                "Archives",
            ]:
                (xcode / name).mkdir(parents=True)
                (xcode / name / "keep-or-delete").write_text("test data")
            with (
                patch.object(Path, "home", return_value=home),
                patch.object(RECLAIM.platform, "system", return_value="Darwin"),
                patch.object(
                    RECLAIM.subprocess,
                    "run",
                    return_value=subprocess.CompletedProcess([], 1),
                ),
                patch.object(
                    sys,
                    "argv",
                    [str(SCRIPT), "xcode", "--device-support", "old", "--apply"],
                ),
            ):
                RECLAIM.main()
            self.assertFalse((xcode / "DerivedData").exists())
            self.assertFalse((xcode / "iOS DeviceSupport/old").exists())
            for name in ["iOS DeviceSupport/new", "UserData", "Archives"]:
                self.assertEqual(
                    (xcode / name / "keep-or-delete").read_text(), "test data"
                )

    def test_rejects_symlink_and_path_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory).resolve()
            outside = home / "important"
            outside.mkdir()
            (home / "Library").symlink_to(outside)
            with self.assertRaises(ValueError):
                RECLAIM.xcode_cleanup_targets(home, [])
            for version in ["..", "/tmp", "../../UserData"]:
                with self.subTest(version=version), self.assertRaises(ValueError):
                    RECLAIM.xcode_cleanup_targets(home, [version])
            self.assertTrue(outside.exists())

    def test_only_symlink_mode_differences_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory).resolve()
            for flags, accepted in [
                (".L...p......", True),
                ("cLc..p......", False),
                (".f...p......", False),
                ("*deleting", False),
            ]:
                with (
                    self.subTest(flags=flags),
                    patch.object(
                        RECLAIM.subprocess,
                        "run",
                        return_value=subprocess.CompletedProcess(
                            [], 0, stdout=f"{flags} example\n", stderr=""
                        ),
                    ),
                ):
                    if accepted:
                        RECLAIM.verify_fg_copy(
                            source, "nuc:/home/emiller/src/fg-mactraitor-20261003/"
                        )
                    else:
                        with self.assertRaisesRegex(ValueError, "mirror is not exact"):
                            RECLAIM.verify_fg_copy(
                                source, "nuc:/home/emiller/src/fg-mactraitor-20261003/"
                            )

    @unittest.skipUnless(shutil.which("rsync"), "rsync is required")
    def test_same_size_same_timestamp_corruption_blocks_fg_removal(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory).resolve()
            source = home / "src/fg"
            destination = home / "remote-copy"
            source.mkdir(parents=True)
            destination.mkdir()
            (source / "data").write_text("original")
            (destination / "data").write_text("modified")
            for path in [source, destination, source / "data", destination / "data"]:
                os.utime(path, (1700000000, 1700000000))
            real_run = subprocess.run

            def local_transport(command, **kwargs):
                if command[0] == "ssh":
                    return subprocess.CompletedProcess(command, 0)
                return real_run([*command[:-1], f"{destination}/"], **kwargs)

            with (
                patch.object(Path, "home", return_value=home),
                patch.object(RECLAIM.platform, "system", return_value="Darwin"),
                patch.object(RECLAIM.subprocess, "run", side_effect=local_transport),
                patch.object(
                    sys,
                    "argv",
                    [
                        str(SCRIPT),
                        "fg",
                        "--apply",
                        "--verified-copy",
                        "nuc:/home/emiller/src/fg-mactraitor-20261003/",
                    ],
                ),
                self.assertRaisesRegex(ValueError, "mirror is not exact"),
            ):
                RECLAIM.main()
            self.assertEqual((source / "data").read_text(), "original")
            self.assertFalse((home / "src/fg.offload-verified").exists())


if __name__ == "__main__":
    unittest.main()
