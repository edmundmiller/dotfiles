import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "flake.nix"
PACKAGE = ROOT / "packages/oxlint-plugin-jev"
DOCS = ROOT / "docs/agents/oxlint.md"


class OxlintJevTests(unittest.TestCase):
    def test_pins_match_vendored_fork_and_plugin_api(self) -> None:
        manifest = json.loads((PACKAGE / "package.json").read_text())
        lock = json.loads((PACKAGE / "package-lock.json").read_text())
        package_nix = (PACKAGE / "default.nix").read_text()

        self.assertEqual(manifest["dependencies"]["oxlint-plugin-jev"], "file:vendor/oxlint-plugin-jev")
        self.assertEqual(manifest["dependencies"]["oxlint"], "1.86.0")
        self.assertEqual(manifest["dependencies"]["@oxlint/plugins"], "1.86.0")
        self.assertEqual(
            lock["packages"]["node_modules/oxlint-plugin-jev"]["version"],
            "0.1.3",
        )
        self.assertNotIn("link", lock["packages"]["node_modules/oxlint-plugin-jev"])
        self.assertEqual(lock["packages"]["node_modules/oxlint"]["version"], "1.86.0")
        self.assertIn('"--install-links"', package_nix)
        provenance = (PACKAGE / "vendor/oxlint-plugin-jev/UPSTREAM.md").read_text()
        self.assertIn("fd3e4b1ad3b8fa7c0d08cdc92633e33c7e662f9e", provenance)
        self.assertTrue((PACKAGE / "vendor/oxlint-plugin-jev/LICENSE").is_file())

    def test_starter_rules_are_yes_no_questions(self) -> None:
        rules = json.loads((PACKAGE / "rules.json").read_text())
        ids = [rule["id"] for rule in rules]
        targets = {rule["target"] for rule in rules}

        self.assertEqual(ids, ["no-pii-in-logs", "no-secrets-in-logs", "name-matches-behavior"])
        self.assertEqual([rule["cutoff"] for rule in rules], [0.8, 0.8, 0.6])
        self.assertEqual([rule["target"] for rule in rules], ["call", "call", "function"])
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
        self.assertIn("op://", DOCS.read_text())
        self.assertIn(".envrc.local", DOCS.read_text())

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
        self.assertEqual(len(baseline), 15)
        self.assertEqual(set(baseline.values()), {"error"})
        self.assertIn("anti-slop/no-conditional-empty-object-spread", baseline)
        config = json.loads((ROOT / "packages/anti-slop-proposal/oxlint.json").read_text())
        self.assertEqual([p["name"] for p in config["jsPlugins"]], ["anti-slop", "anti-slop-martinfowler", "anti-slop-effect"])
        self.assertFalse(any("jev" in name for name in config["rules"]))
        self.assertEqual(config["rules"]["anti-slop-martinfowler/message-chains"], "off")
        self.assertEqual(config["overrides"][0]["files"], ["**/packages/callstack-diff/**"])
        nodes = json.loads((ROOT / "flake.lock").read_text())["nodes"]
        self.assertEqual(nodes["anti-slop"]["locked"]["rev"], "446268e5d15baa968eaec669ff65358d36ae6259")
        locked = nodes["anti-slop-incoming"]["locked"]
        self.assertEqual(locked["owner"], "K-Mistele")
        self.assertEqual(locked["rev"], "b7c1619b4d51b4815e89ba3700a975a6ec54b8c3")
        manifest = json.loads((ROOT / "packages/anti-slop-proposal/package.json").read_text())
        self.assertEqual(manifest["dependencies"], {"oxlint": "1.86.0", "@oxlint/plugins": "1.86.0"})
        ordinary = json.loads((ROOT / "packages/anti-slop/package.json").read_text())
        self.assertEqual(ordinary["dependencies"], {"@oxlint/plugins": "1.78.0"})


if __name__ == "__main__":
    unittest.main()
