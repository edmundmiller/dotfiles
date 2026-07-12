import json
import tempfile
import unittest
from pathlib import Path

from package_harness import HarnessError, Unit, commands_for, discover, load_metadata, repo_root, resolve_unit


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

    def test_constructs_checkout_patch_and_check_commands_in_order(self):
        path = self.declare("overlays", "demo")
        unit = Unit("overlays", "demo", path)
        checkout = self.root / "checkout"
        metadata = {
            "source": "https://example.test/repo.git",
            "ref": "v1.2.3",
            "patches": ["patches/one.patch", "patches/two.patch"],
            "checks": [["python", "-m", "unittest"], ["tool", "check"]],
        }

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


if __name__ == "__main__":
    unittest.main()
