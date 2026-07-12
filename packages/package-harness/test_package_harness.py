import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

from package_harness import HarnessError, Unit, check, commands_for, discover, load_metadata, main, repo_root, resolve_unit


class HarnessTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        (self.root / "flake.nix").touch()
        (self.root / "overlays").mkdir()
        (self.root / "packages").mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def declare(self, group, name, metadata=None):
        unit = self.root / group / name
        unit.mkdir()
        if metadata is not None:
            (unit / "package-harness.json").write_text(json.dumps(metadata))
        return unit

    @staticmethod
    def metadata(source="https://example.test/repo.git", ref="v1", patches=None, checks=None):
        return {
            "source": source,
            "ref": ref,
            "patches": patches or [],
            "checks": checks or [["python3", "-c", "pass"]],
        }

    def create_upstream_and_patch(self, unit_path):
        upstream = self.root / "upstream"
        upstream.mkdir()
        subprocess.run(["git", "init", "-q", upstream], check=True)
        subprocess.run(["git", "-C", upstream, "config", "user.email", "test@example.com"], check=True)
        subprocess.run(["git", "-C", upstream, "config", "user.name", "Test User"], check=True)
        tracked = upstream / "value.txt"
        tracked.write_text("before\n")
        subprocess.run(["git", "-C", upstream, "add", "value.txt"], check=True)
        subprocess.run(["git", "-C", upstream, "commit", "-qm", "initial"], check=True)
        ref = subprocess.run(
            ["git", "-C", upstream, "rev-parse", "HEAD"], check=True, capture_output=True, text=True
        ).stdout.strip()
        tracked.write_text("after\n")
        patch_text = subprocess.run(
            ["git", "-C", upstream, "diff", "--", "value.txt"], check=True, capture_output=True, text=True
        ).stdout
        subprocess.run(["git", "-C", upstream, "checkout", "--", "value.txt"], check=True)
        patch_path = unit_path / "patches" / "nested" / "change.patch"
        patch_path.parent.mkdir(parents=True)
        patch_path.write_text(patch_text)
        return upstream, ref, patch_path

    def test_discovers_first_level_files_and_directories_from_nested_directory(self):
        self.declare("overlays", "hunk", {})
        (self.root / "packages" / "hey.nix").touch()
        nested = self.root / "packages" / "hunk" / "nested"
        nested.mkdir(parents=True)

        self.assertEqual(repo_root(nested), self.root)
        self.assertEqual(
            [(unit.group, unit.name) for unit in discover(self.root)],
            [("overlays", "hunk"), ("packages", "hey"), ("packages", "hunk")],
        )

    def test_resolve_reports_missing_ambiguous_and_undeclared_units(self):
        with self.assertRaisesRegex(HarnessError, "unit 'missing' not found"):
            resolve_unit(self.root, "missing")
        self.declare("packages", "plain")
        with self.assertRaisesRegex(HarnessError, "is undeclared \\(missing package-harness.json\\)"):
            resolve_unit(self.root, "plain")
        self.declare("packages", "shared")
        self.declare("overlays", "shared")
        with self.assertRaisesRegex(HarnessError, "ambiguous: overlays/shared, packages/shared"):
            resolve_unit(self.root, "shared")

    def test_load_metadata_rejects_non_fixed_schema(self):
        path = self.declare("packages", "bad", {"source": "https://example.test/repo.git"})
        unit = Unit("packages", "bad", path)
        with self.assertRaisesRegex(HarnessError, "expected exactly"):
            load_metadata(unit)

    def test_load_metadata_accepts_nested_patch_path(self):
        path = self.declare("overlays", "demo")
        patch_path = path / "patches" / "nested" / "fix.patch"
        patch_path.parent.mkdir(parents=True)
        patch_path.touch()
        metadata = self.metadata(patches=["patches/nested/fix.patch"])
        (path / "package-harness.json").write_text(json.dumps(metadata))

        self.assertEqual(load_metadata(Unit("overlays", "demo", path)), metadata)

    def test_load_metadata_rejects_unsafe_or_missing_patch_paths(self):
        path = self.declare("overlays", "demo")
        outside = self.root / "outside.patch"
        outside.touch()
        symlink = path / "escape.patch"
        symlink.symlink_to(outside)
        unit = Unit("overlays", "demo", path)

        for bad_path in (str(outside), "../outside.patch", "escape.patch", "missing.patch"):
            with self.subTest(path=bad_path):
                (path / "package-harness.json").write_text(json.dumps(self.metadata(patches=[bad_path])))
                with self.assertRaisesRegex(HarnessError, f"invalid metadata {unit.metadata_path}"):
                    load_metadata(unit)

    def test_constructs_checkout_patch_and_check_commands_in_order(self):
        path = self.declare("overlays", "demo")
        unit = Unit("overlays", "demo", path)
        checkout = self.root / "checkout"
        metadata = self.metadata(
            ref="v1.2.3",
            patches=["patches/one.patch", "patches/two.patch"],
            checks=[["python", "-m", "unittest"], ["tool", "check"]],
        )

        self.assertEqual(
            commands_for(unit, checkout, metadata),
            [
                ["git", "clone", "--no-checkout", metadata["source"], str(checkout)],
                ["git", "-C", str(checkout), "checkout", "--detach", metadata["ref"]],
                ["git", "-C", str(checkout), "apply", str((path / "patches/one.patch").resolve())],
                ["git", "-C", str(checkout), "apply", str((path / "patches/two.patch").resolve())],
                ["python", "-m", "unittest"],
                ["tool", "check"],
            ],
        )

    def test_check_clones_applies_patch_and_runs_check_in_checkout(self):
        path = self.declare("overlays", "demo")
        upstream, ref, _ = self.create_upstream_and_patch(path)
        check_code = (
            "from pathlib import Path; "
            "assert Path.cwd().name == 'upstream'; "
            "assert Path('value.txt').read_text() == 'after\\n'"
        )
        metadata = self.metadata(
            source=str(upstream),
            ref=ref,
            patches=["patches/nested/change.patch"],
            checks=[[sys.executable, "-c", check_code]],
        )
        (path / "package-harness.json").write_text(json.dumps(metadata))

        check(Unit("overlays", "demo", path))

    def test_missing_check_executable_returns_clean_exit_two(self):
        path = self.declare("overlays", "demo")
        upstream, ref, _ = self.create_upstream_and_patch(path)
        metadata = self.metadata(
            source=str(upstream),
            ref=ref,
            patches=["patches/nested/change.patch"],
            checks=[["definitely-missing-package-harness-command"]],
        )
        (path / "package-harness.json").write_text(json.dumps(metadata))
        stderr = io.StringIO()

        with patch("package_harness.repo_root", return_value=self.root), redirect_stderr(stderr):
            self.assertEqual(main(["pkg-check", "demo"]), 2)

        message = stderr.getvalue()
        self.assertIn("definitely-missing-package-harness-command", message)
        self.assertIn("upstream", message)
        self.assertNotIn("Traceback", message)

    def test_hunk_metadata_matches_locked_input(self):
        root_value = os.environ.get("PACKAGE_HARNESS_REPO_ROOT")
        self.assertIsNotNone(root_value, "PACKAGE_HARNESS_REPO_ROOT is required")
        root = Path(root_value)
        metadata = json.loads((root / "overlays/hunk/package-harness.json").read_text())
        self.assertIsInstance(metadata, dict, "Hunk metadata must be an object")
        for field in ("source", "ref"):
            self.assertIsInstance(metadata.get(field), str, f"Hunk metadata {field} must be a string")
        lock = json.loads((root / "flake.lock").read_text())
        root_node_id = lock.get("root")
        self.assertIsInstance(root_node_id, str, "flake.lock root must be a node id")
        root_node = lock.get("nodes", {}).get(root_node_id)
        self.assertIsInstance(root_node, dict, "flake.lock root node is missing")
        hunk_node_id = root_node.get("inputs", {}).get("hunk")
        self.assertIsInstance(hunk_node_id, str, "flake.lock root input hunk must be a node id")
        original = lock.get("nodes", {}).get(hunk_node_id, {}).get("original")
        self.assertIsInstance(original, dict, "flake.lock Hunk original metadata is missing")
        for field in ("owner", "repo", "ref"):
            self.assertIsInstance(original.get(field), str, f"flake.lock Hunk original.{field} must be a string")
        self.assertEqual(metadata["source"], f"https://github.com/{original['owner']}/{original['repo']}.git")
        self.assertEqual(metadata["ref"], original["ref"])

    def test_patch_locality_guard(self):
        root_value = os.environ.get("PACKAGE_HARNESS_REPO_ROOT")
        self.assertIsNotNone(root_value, "PACKAGE_HARNESS_REPO_ROOT is required")
        script = Path(root_value) / "bin/check-patch-locality"

        allowed = subprocess.run(
            [
                "bash",
                script,
                "packages/stack/patches/fix.patch",
                "overlays/hunk/patches/fix.patch",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        invalid_cases = [
            (["patches/fix.patch"], "patches/fix.patch"),
            (["misc/fix.patch"], "misc/fix.patch"),
            (["packages/group/tool/patches/fix.patch"], "packages/group/tool/patches/fix.patch"),
            (
                [
                    "packages/stack/patches/fix.patch",
                    "misc/fix.patch",
                    "overlays/hunk/patches/fix.patch",
                ],
                "misc/fix.patch",
            ),
        ]
        for paths, offending_path in invalid_cases:
            with self.subTest(paths=paths):
                rejected = subprocess.run(["bash", script, *paths], capture_output=True, text=True)
                self.assertEqual(rejected.returncode, 1)
                self.assertIn(
                    "Patch must live at packages/<name>/patches/*.patch or overlays/<name>/patches/*.patch",
                    rejected.stderr,
                )
                self.assertIn(offending_path, rejected.stderr)

if __name__ == "__main__":
    unittest.main()
