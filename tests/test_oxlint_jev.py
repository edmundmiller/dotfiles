import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "flake.nix"
PACKAGE = ROOT / "packages/oxlint-plugin-jev"


class OxlintJevTests(unittest.TestCase):
    def test_pins_match_vendored_fork_and_plugin_api(self) -> None:
        manifest = json.loads((PACKAGE / "package.json").read_text())
        lock = json.loads((PACKAGE / "package-lock.json").read_text())
        package_nix = (PACKAGE / "default.nix").read_text()

        self.assertEqual(manifest["dependencies"]["oxlint-plugin-jev"], "file:vendor/oxlint-plugin-jev")
        self.assertEqual(
            manifest["dependencies"]["oxlint"],
            manifest["dependencies"]["@oxlint/plugins"],
        )
        self.assertEqual(
            lock["packages"]["node_modules/oxlint"]["version"],
            manifest["dependencies"]["oxlint"],
        )
        self.assertNotIn("link", lock["packages"]["node_modules/oxlint-plugin-jev"])
        self.assertIn('"--install-links"', package_nix)
        self.assertTrue((PACKAGE / "vendor/oxlint-plugin-jev/LICENSE").is_file())

    def test_starter_rules_are_yes_no_questions(self) -> None:
        rules = json.loads((PACKAGE / "rules.json").read_text())
        targets = {rule["target"] for rule in rules}

        self.assertTrue(targets <= {"function", "call", "jsx", "file"})
        for rule in rules:
            self.assertTrue(rule["question"].endswith("?"))
            self.assertGreaterEqual(rule["cutoff"], 0)
            self.assertLessEqual(rule["cutoff"], 1)

    def test_generated_config_skips_ci_without_a_flake_secret(self) -> None:
        package_nix = (PACKAGE / "default.nix").read_text()
        wrapper = (PACKAGE / "oxlint-jev.sh").read_text()
        flake = FLAKE.read_text()

        self.assertIn('ci: "skip"', (PACKAGE / "plugin.ts").read_text())
        self.assertIn("correctness = \"off\"", package_nix)
        self.assertIn('name = "jev/${rule.id}"', package_nix)
        self.assertNotIn("TYPESAFE_API_KEY", flake)
        self.assertNotIn("TYPESAFE_API_KEY=", package_nix)
        self.assertIn("TYPESAFE_API_KEY_FILE", wrapper)
        self.assertIn('"@lintChanged@"', wrapper)
        self.assertIn('= --presets', wrapper)

    def test_default_oxlint_hook_stays_on_anti_slop(self) -> None:
        flake = FLAKE.read_text()

        self.assertIn(
            'entry = "${antiSlopOxlint}/bin/oxlint --threads=1 --quiet --disable-nested-config --config ${antiSlopConfig}";',
            flake,
        )
        self.assertIn('antiSlopOxlint = inputs.nixpkgs-anti-slop.legacyPackages.${system}.oxlint;', flake)
        self.assertNotIn("jev/ask", flake)
        self.assertIn("oxlint-plugin-jev", flake)
        self.assertIn('oxlint-additions = {', flake)
        self.assertIn('/bin/anti-slop-additions', flake)
        baseline = json.loads((ROOT / "packages/anti-slop/rules.json").read_text())
        self.assertEqual(set(baseline.values()), {"error"})
        config = json.loads((ROOT / "packages/anti-slop-proposal/oxlint.json").read_text())
        self.assertFalse(any("jev" in name for name in config["rules"]))


if __name__ == "__main__":
    unittest.main()
