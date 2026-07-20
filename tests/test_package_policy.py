import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PackagePolicyTest(unittest.TestCase):
    def test_pi_policy_bridge_uses_nix_managed_runtime_path(self):
        settings = (ROOT / "config/pi/settings.jsonc").read_text()
        home_files = (ROOT / "modules/agents/pi/lib/_home-files.nix").read_text()
        runtime_path = "~/.pi/agent/packages/pi-command-policy-bridge"
        self.assertIn(runtime_path, settings)
        self.assertNotIn(
            "~/.config/dotfiles/packages/pi-packages/pi-command-policy-bridge", settings
        )
        self.assertIn('".pi/agent/packages/pi-command-policy-bridge".source', home_files)

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

    def test_package_layout_guard(self):
        script = ROOT / "bin/check-package-layout"
        flat_packages = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "packages").glob("*.nix"))

        current_tree = subprocess.run(
            ["bash", script, *flat_packages],
            capture_output=True,
            text=True,
        )
        self.assertEqual(current_tree.returncode, 0, current_tree.stderr)

        allowed = subprocess.run(
            ["bash", script, "packages/sem.nix", "packages/example/default.nix"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(allowed.returncode, 0, allowed.stderr)

        rejected = subprocess.run(
            ["bash", script, "packages/new-package.nix"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(rejected.returncode, 1)
        self.assertIn(
            "Package must live at packages/<name>/default.nix: packages/new-package.nix",
            rejected.stderr,
        )


if __name__ == "__main__":
    unittest.main()
