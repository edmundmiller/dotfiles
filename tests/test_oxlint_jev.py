import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "flake.nix"
PACKAGE = ROOT / "packages/oxlint-plugin-jev"
DOCS = ROOT / "docs/agents/oxlint.md"


class OxlintJevTests(unittest.TestCase):
    def test_pins_match_published_plugin_and_oxlint(self) -> None:
        manifest = json.loads((PACKAGE / "package.json").read_text())
        lock = json.loads((PACKAGE / "package-lock.json").read_text())
        package_nix = (PACKAGE / "default.nix").read_text()

        self.assertEqual(manifest["dependencies"]["oxlint-plugin-jev"], "0.1.1")
        self.assertEqual(manifest["dependencies"]["oxlint"], "1.83.0")
        self.assertEqual(
            lock["packages"]["node_modules/oxlint-plugin-jev"]["version"],
            "0.1.1",
        )
        self.assertEqual(lock["packages"]["node_modules/oxlint"]["version"], "1.83.0")
        self.assertIn('jevVersion == "0.1.1"', package_nix)
        self.assertIn('oxlintVersion == "1.83.0"', package_nix)

    def test_starter_rules_are_yes_no_questions(self) -> None:
        rules = json.loads((PACKAGE / "rules.json").read_text())
        ids = [rule["id"] for rule in rules]
        targets = {rule["target"] for rule in rules}

        self.assertIn("no-pii-in-logs", ids)
        self.assertTrue(targets <= {"function", "call", "jsx", "file"})
        for rule in rules:
            self.assertTrue(rule["question"].endswith("?"))
            self.assertGreaterEqual(rule["cutoff"], 0)
            self.assertLessEqual(rule["cutoff"], 1)

    def test_generated_config_skips_ci_without_a_flake_secret(self) -> None:
        package_nix = (PACKAGE / "default.nix").read_text()
        wrapper = (PACKAGE / "oxlint-jev.sh").read_text()
        flake = FLAKE.read_text()

        self.assertIn('ci = "skip"', package_nix)
        self.assertIn("correctness = \"off\"", package_nix)
        self.assertIn('"jev/ask"', package_nix)
        self.assertNotIn("TYPESAFE_API_KEY", flake)
        self.assertNotIn("TYPESAFE_API_KEY=", package_nix)
        self.assertIn("TYPESAFE_API_KEY_FILE", wrapper)
        self.assertIn("op://", DOCS.read_text())
        self.assertIn(".envrc.local", DOCS.read_text())

    def test_default_oxlint_hook_stays_on_anti_slop(self) -> None:
        flake = FLAKE.read_text()

        self.assertIn(
            'entry = "${antiSlopOxlint}/bin/oxlint --threads=1 --quiet --disable-nested-config --config ${antiSlopConfig}";',
            flake,
        )
        self.assertIn("nixpkgs-anti-slop", flake)
        self.assertNotIn("jev/ask", flake)
        self.assertIn("oxlint-plugin-jev", flake)
        self.assertIn("packages.oxlint-plugin-jev", flake)


if __name__ == "__main__":
    unittest.main()
