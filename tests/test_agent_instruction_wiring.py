import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OMP_MODULE = ROOT / "modules" / "agents" / "omp" / "default.nix"
CODEX_MODULE = ROOT / "modules" / "agents" / "codex" / "default.nix"
PI_MODULE = ROOT / "modules" / "agents" / "pi" / "default.nix"
OMP_CORE = ROOT / "config" / "agents" / "core.md"
FIX_AGENTS_COMMAND = ROOT / "config" / "omp" / "commands" / "fix-agents-md.md"


class AgentInstructionWiringTests(unittest.TestCase):
    def test_omp_uses_bounded_core_without_changing_codex_or_pi(self) -> None:
        core = OMP_CORE.read_text()
        normalized_core = " ".join(core.split())
        omp_module = OMP_MODULE.read_text()

        self.assertLessEqual(len(core.split()), 250)
        for invariant in (
            "Preserve unrelated work and stay within the user's requested scope.",
            "Do not infer authority",
            "Distinguish verified facts, user-provided facts, assumptions, and unknowns.",
            "Do not claim completion without fresh evidence",
        ):
            self.assertIn(invariant, normalized_core)

        self.assertIn('agentCore = builtins.readFile "${configDir}/agents/core.md";', omp_module)
        self.assertIn('home.file.".omp/agent/AGENTS.md".text = agentCore;', omp_module)
        self.assertNotIn('home.file.".omp/agent/AGENTS.md".text = concatenatedRules;', omp_module)
        self.assertNotIn('home.file.".omp/agent/rules/incremental-architecture.md"', omp_module)

        for module in (CODEX_MODULE, PI_MODULE):
            with self.subTest(module=module):
                self.assertIn("rulesDir", module.read_text())
                self.assertIn("concatenatedRules", module.read_text())

    def test_agents_md_use_guarded_hey_interfaces(self) -> None:
        root_agents = (ROOT / "AGENTS.md").read_text()
        for command in ("hey re", "hey skills-update", "hey skills-sync"):
            self.assertIn(command, root_agents)

        rejected = (
            "sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .",
            "nix flake update skills-catalog",
        )
        offenders = []
        for path in ROOT.rglob("AGENTS.md"):
            if any(part in {".git", "node_modules"} for part in path.parts):
                continue
            text = path.read_text()
            offenders.extend(
                f"{path.relative_to(ROOT)}: {command}"
                for command in rejected
                if command in text
            )

        self.assertEqual([], offenders)

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

        behavior = next(
            item for item in manifest["checks"] if item["id"] == "agent-quality-tests"
        )
        self.assertIn("tests/test_omp_ttsr_rules.py", behavior["command"])

    def test_pre_commit_hook_runs_rule_and_skill_checks(self) -> None:
        flake = (ROOT / "flake.nix").read_text()
        start = flake.index("agent-instructions = {")
        hook = flake[start : start + 1200]
        self.assertIn("check-agent-rules", hook)
        self.assertIn("skill-quality/scripts/validate.py", hook)
        self.assertIn('stages = [ "pre-commit" ]', hook)

        self.assertIn("omp-thin-harness = {", flake)
        self.assertIn("tests/test_omp_ttsr_rules.py", flake)
        self.assertIn(r"config/agents/core\\.md", flake)


if __name__ == "__main__":
    unittest.main()
