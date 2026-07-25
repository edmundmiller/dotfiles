import json
import re
import subprocess
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


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

        validated = subprocess.run(
            [
                "python3",
                ROOT / "bin/import-renovate-patch-repair",
                "hunk",
                ROOT,
                "--trusted-metadata",
                ROOT / "overlays/hunk/package-harness.json",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(validated.returncode, 0, validated.stderr)

    def test_herdr_metadata_matches_overlay(self):
        metadata = json.loads((ROOT / "overlays/herdr/package-harness.json").read_text())
        overlay = (ROOT / "overlays/herdr/default.nix").read_text()
        revision = re.search(r'\brev = "([^"]+)";', overlay)
        self.assertIsNotNone(revision, "Herdr overlay revision is missing")
        self.assertEqual(metadata["source"], "https://github.com/ogulcancelik/herdr.git")
        self.assertEqual(metadata["ref"], revision.group(1))

        validated = subprocess.run(
            [
                "python3",
                ROOT / "bin/import-renovate-patch-repair",
                "herdr",
                ROOT,
                "--trusted-metadata",
                ROOT / "overlays/herdr/package-harness.json",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(validated.returncode, 0, validated.stderr)

        with TemporaryDirectory() as temporary:
            trusted = Path(temporary) / "package-harness.json"
            trusted.write_text(json.dumps({**metadata, "checks": [["false"]]}) + "\n")
            rejected = subprocess.run(
                [
                    "python3",
                    ROOT / "bin/import-renovate-patch-repair",
                    "herdr",
                    ROOT,
                    "--trusted-metadata",
                    trusted,
                ],
                capture_output=True,
                text=True,
            )
        self.assertEqual(rejected.returncode, 1)
        self.assertIn("checks differs from trusted base", rejected.stderr)

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

    def test_renovate_patch_repair_uses_trusted_agent_shell(self):
        agent = (ROOT / ".flue/agents/renovate-patch-repair.ts").read_text()
        command = "nix develop /trusted#agent --command pkg-check <target>"
        self.assertIn(command, agent)
        self.assertNotIn("nix develop --command pkg-check <target>", agent)

    def test_renovate_patch_repair_path_guard(self):
        script = ROOT / "bin/check-renovate-patch-paths"
        allowed = {
            "herdr": [
                "overlays/herdr/default.nix",
                "overlays/herdr/package-harness.json",
                "overlays/herdr/patches/0001-fix.patch",
            ],
            "hunk": [
                "flake.nix",
                "flake.lock",
                "overlays/hunk/package-harness.json",
                "overlays/hunk/patches/0001-fix.patch",
            ],
        }

        for target, paths in allowed.items():
            with self.subTest(target=target):
                accepted = subprocess.run(
                    ["bash", script, target, *paths],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(accepted.returncode, 0, accepted.stderr)

        rejected_cases = [
            ("herdr", "flake.nix"),
            ("herdr", ".github/workflows/renovate-patch-repair.yml"),
            ("hunk", "overlays/herdr/default.nix"),
            ("hunk", "overlays/hunk/patches/nested/fix.patch"),
        ]
        for target, path in rejected_cases:
            with self.subTest(target=target, path=path):
                rejected = subprocess.run(
                    ["bash", script, target, path],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(rejected.returncode, 1)
                self.assertIn(f"Renovate {target} repair cannot change: {path}", rejected.stderr)

        unknown = subprocess.run(
            ["bash", script, "other", "flake.nix"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(unknown.returncode, 2)
        self.assertIn("usage:", unknown.stderr)

    def test_renovate_patch_repair_importer(self):
        script = ROOT / "bin/import-renovate-patch-repair"
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            destination = root / "destination"
            for workspace in (source, destination):
                (workspace / "overlays/hunk/patches").mkdir(parents=True)
                (workspace / "flake.nix").write_text("old flake\n")
                (workspace / "flake.lock").write_text("old lock\n")

            old_harness = {
                "source": "https://example.test/hunk.git",
                "ref": "v1.0.0",
                "patches": ["patches/0001-delete.patch"],
                "checks": [["bun", "test"]],
            }
            (destination / "overlays/hunk/package-harness.json").write_text(
                json.dumps(old_harness, indent=2) + "\n"
            )
            (destination / "overlays/hunk/patches/0001-delete.patch").write_text("delete\n")
            (source / "flake.nix").write_text("malicious flake\n")
            (source / "flake.lock").write_text("malicious lock\n")
            (source / "overlays/hunk/package-harness.json").write_text("{}\n")
            (source / "overlays/hunk/patches/0002-add.patch").write_text("add\n")

            imported = subprocess.run(
                ["python3", script, "hunk", source, destination],
                capture_output=True,
                text=True,
            )
            self.assertEqual(imported.returncode, 0, imported.stderr)
            self.assertEqual((destination / "flake.nix").read_text(), "old flake\n")
            self.assertEqual((destination / "flake.lock").read_text(), "old lock\n")
            imported_harness = json.loads(
                (destination / "overlays/hunk/package-harness.json").read_text()
            )
            self.assertEqual(
                imported_harness,
                {**old_harness, "patches": ["patches/0002-add.patch"]},
            )
            self.assertFalse(
                (destination / "overlays/hunk/patches/0001-delete.patch").exists()
            )
            self.assertEqual(
                (destination / "overlays/hunk/patches/0002-add.patch").read_text(),
                "add\n",
            )
            (source / "overlays/hunk/patches/not-a-patch.txt").write_text("reject\n")
            rejected_extra = subprocess.run(
                ["python3", script, "hunk", source, destination],
                capture_output=True,
                text=True,
            )
            self.assertEqual(rejected_extra.returncode, 1)
            self.assertIn("Invalid patch artifact:", rejected_extra.stderr)

        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            destination = root / "destination"
            for workspace in (source, destination):
                (workspace / "overlays/herdr/patches").mkdir(parents=True)
            original = """src = fetch {
  rev = "v1.0.0";
  hash = "sha256-original";
    patches = [
      ./patches/0001-keep.patch # keep this
    ];
};
"""
            (destination / "overlays/herdr/default.nix").write_text(original)
            (destination / "overlays/herdr/patches/0001-keep.patch").write_text("old\n")
            old_herdr_harness = {
                "source": "https://example.test/herdr.git",
                "ref": "v1.0.0",
                "patches": ["patches/0001-keep.patch"],
                "checks": [["nix", "build", "--no-link"]],
            }
            (destination / "overlays/herdr/package-harness.json").write_text(
                json.dumps(old_herdr_harness, indent=2) + "\n"
            )
            (source / "overlays/herdr/default.nix").write_text(
                original.replace("v1.0.0", "v0.0.0")
            )
            (source / "overlays/herdr/patches/0001-keep.patch").write_text("updated\n")
            (source / "overlays/herdr/patches/0002-add.patch").write_text("added\n")
            (source / "overlays/herdr/package-harness.json").write_text(
                json.dumps(
                    {
                        "source": "https://malicious.test/herdr.git",
                        "ref": "v0.0.0",
                        "patches": [
                            "patches/0001-keep.patch",
                            "patches/0002-add.patch",
                        ],
                        "checks": [["false"]],
                    },
                    indent=2,
                )
                + "\n"
            )

            imported = subprocess.run(
                ["python3", script, "herdr", source, destination],
                capture_output=True,
                text=True,
            )
            self.assertEqual(imported.returncode, 0, imported.stderr)
            manifest = (destination / "overlays/herdr/default.nix").read_text()
            self.assertIn('rev = "v1.0.0";', manifest)
            self.assertNotIn('rev = "v0.0.0";', manifest)
            self.assertIn("./patches/0001-keep.patch # keep this", manifest)
            self.assertIn("./patches/0002-add.patch", manifest)
            imported_harness = json.loads(
                (destination / "overlays/herdr/package-harness.json").read_text()
            )
            self.assertEqual(
                imported_harness,
                {
                    **old_herdr_harness,
                    "patches": [
                        "patches/0001-keep.patch",
                        "patches/0002-add.patch",
                    ],
                },
            )

            (source / "overlays/herdr/default.nix").unlink()
            (source / "overlays/herdr/default.nix").symlink_to("/etc/passwd")
            rejected_symlink = subprocess.run(
                ["python3", script, "herdr", source],
                capture_output=True,
                text=True,
            )
            self.assertEqual(rejected_symlink.returncode, 1)
            self.assertIn("Expected regular file:", rejected_symlink.stderr)

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
