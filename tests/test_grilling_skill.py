from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "skills/flake.nix"


class GrillingSkillContractTests(unittest.TestCase):
    def test_transform_targets_grilling_instead_of_launcher(self) -> None:
        flake = FLAKE.read_text(encoding="utf-8")
        launcher = flake.index("                  grill-me = {")
        grilling = flake.index("                  grilling = {", launcher)
        transform = flake.index("                    transform =", grilling)

        self.assertNotIn("transform =", flake[launcher:grilling])
        self.assertLess(grilling, transform)
        self.assertIn('"grilling"', flake[flake.index("lib.filter ("):launcher])

    def test_transform_routes_each_supported_runtime_to_its_dialog(self) -> None:
        flake = FLAKE.read_text(encoding="utf-8")
        grilling = flake.index("                  grilling = {")
        contract = flake[grilling : flake.index("                }\n                // mattpocockExplicit", grilling)]

        for phrase in (
            "Do not print the frontier as",
            "In OMP, use `ask`",
            "In Codex, use `request_user_input`",
            "calls of at most three questions",
            "In Pi, use `ask_user`",
            "Only fall back to the Markdown format",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, contract)


if __name__ == "__main__":
    unittest.main()
