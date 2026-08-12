import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OMP_MODULE = ROOT / "modules" / "agents" / "omp" / "default.nix"
FIX_AGENTS_COMMAND = ROOT / "config" / "omp" / "commands" / "fix-agents-md.md"


class AgentInstructionWiringTests(unittest.TestCase):
    def test_omp_installs_fix_agents_md_prompt_template(self) -> None:
        prompt = FIX_AGENTS_COMMAND.read_text()
        module = OMP_MODULE.read_text()

        self.assertIn(
            "I want you to refactor my AGENTS.md file to follow progressive disclosure principles.",
            prompt,
        )
        self.assertIn("1. **Find contradictions**", prompt)
        self.assertIn("5. **Flag for deletion**", prompt)
        self.assertIn('home.file.".omp/agent/commands/fix-agents-md.md"', module)
        self.assertIn('source = "${configDir}/omp/commands/fix-agents-md.md";', module)

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
