import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PackagePolicyTest(unittest.TestCase):
    def test_hunk_metadata_matches_locked_input(self):
        metadata = json.loads((ROOT / "overlays/hunk/package-harness.json").read_text())
        self.assertIsInstance(metadata, dict, "Hunk metadata must be an object")
        for field in ("source", "ref"):
            self.assertIsInstance(metadata.get(field), str, f"Hunk metadata {field} must be a string")
        lock = json.loads((ROOT / "flake.lock").read_text())
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
        script = ROOT / "bin/check-patch-locality"

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
