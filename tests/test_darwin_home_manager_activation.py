import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules" / "darwin-home-manager.nix"
SKILLS_FLAKE = ROOT / "skills" / "flake.nix"


class DarwinHomeManagerActivationTests(unittest.TestCase):
    def test_bash_compatibility_is_set_before_activation_heredocs(self) -> None:
        module = MODULE.read_text()

        self.assertIn('entryBefore [ "checkLinkTargets" ]', module)
        self.assertIn("export BASH_COMPAT=50", module)

    def test_skill_bundle_builds_use_bash_5_0_compatibility_on_darwin(self) -> None:
        skills_flake = SKILLS_FLAKE.read_text()

        self.assertIn("if pkgs.stdenv.isDarwin then", skills_flake)
        self.assertIn('BASH_COMPAT = "50";', skills_flake)


if __name__ == "__main__":
    unittest.main()
