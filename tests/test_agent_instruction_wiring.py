import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AgentInstructionWiringTests(unittest.TestCase):
    def test_finish_manifest_runs_rule_and_skill_checks(self) -> None:
        manifest = json.loads((ROOT / ".agents" / "quality.json").read_text())
        check = next(item for item in manifest["checks"] if item["id"] == "agent-instructions")
        self.assertIn("bin/check-agent-rules", check["command"])
        self.assertIn("skill-quality/scripts/validate.py", check["command"])

    def test_pre_commit_hook_runs_rule_and_skill_checks(self) -> None:
        flake = (ROOT / "flake.nix").read_text()
        start = flake.index("agent-instructions = {")
        hook = flake[start : start + 1200]
        self.assertIn("check-agent-rules", hook)
        self.assertIn("skill-quality/scripts/validate.py", hook)
        self.assertIn('stages = [ "pre-commit" ]', hook)


if __name__ == "__main__":
    unittest.main()
