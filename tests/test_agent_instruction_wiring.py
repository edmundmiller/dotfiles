import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OMP_MODULE = ROOT / "modules" / "agents" / "omp" / "default.nix"
CODEX_MODULE = ROOT / "modules" / "agents" / "codex" / "default.nix"
PI_MODULE = ROOT / "modules" / "agents" / "pi" / "default.nix"
OMP_CORE = ROOT / "config" / "agents" / "core.md"
FIX_AGENTS_COMMAND = ROOT / "config" / "omp" / "commands" / "fix-agents-md.md"
THREAD_INTROSPECTION = ROOT / "config" / "omp" / "prompts" / "thread-introspection.md"


class AgentInstructionWiringTests(unittest.TestCase):
    def test_omp_and_codex_use_bounded_core_without_changing_pi(self) -> None:
        core = OMP_CORE.read_text()
        normalized_core = " ".join(core.split())
        omp_module = OMP_MODULE.read_text()
        codex_module = CODEX_MODULE.read_text()

        self.assertLessEqual(len(core.split()), 220)
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

        self.assertIn('agentCore = builtins.readFile "${configDir}/agents/core.md";', codex_module)
        self.assertIn('".codex/AGENTS.md".text = agentCore;', codex_module)
        self.assertNotIn("rulesDir", codex_module)
        self.assertNotIn("concatenatedRules", codex_module)

        pi_module = PI_MODULE.read_text()
        self.assertIn("rulesDir", pi_module)
        self.assertIn("concatenatedRules", pi_module)

        self.assertNotIn("For ADHD resources", core)

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

    def test_thread_introspection_cannot_expand_startup_rules(self) -> None:
        prompt = THREAD_INTROSPECTION.read_text()
        module = OMP_MODULE.read_text()

        self.assertNotIn("- `config/agents/rules/*.md`", prompt)
        self.assertIn(
            "Never edit `config/agents/core.md` or `config/agents/rules/` from session mining.",
            prompt,
        )
        self.assertNotIn('path.startswith("config/agents/rules/")', module)
        self.assertIn('path.startswith("config/omp/prompts/")', module)

    def test_finish_manifest_runs_rule_and_skill_checks(self) -> None:
        manifest = json.loads((ROOT / ".agents" / "quality.json").read_text())
        check = next(item for item in manifest["checks"] if item["id"] == "agent-instructions")
        self.assertIn("bin/check-agent-rules", check["command"])
        self.assertIn("skill-quality/scripts/validate.py", check["command"])

        behavior = next(
            item for item in manifest["checks"] if item["id"] == "agent-quality-tests"
        )
        self.assertIn("tests/test_omp_ttsr_rules.py", behavior["command"])
        self.assertIn("tests/test_codex_model_config.py", behavior["command"])
        self.assertIn("tests/test_claude_activation.py", behavior["command"])
        self.assertIn("tests/test_darwin_home_manager_activation.py", behavior["command"])
        self.assertIn("tests/test_hermes_local_wiring.py", behavior["command"])
        self.assertIn("tests/test_done_skill.py", behavior["command"])

    def test_nix_thin_harness_runs_codex_model_config_tests(self) -> None:
        flake = (ROOT / "flake.nix").read_text()
        start = flake.index("omp-thin-harness-tests =")
        check = flake[start : start + 900]

        self.assertIn("tests/test_codex_model_config.py", check)

    def test_pre_commit_hook_runs_rule_and_skill_checks(self) -> None:
        flake = (ROOT / "flake.nix").read_text()
        start = flake.index("agent-instructions = {")
        hook = flake[start : start + 1200]
        self.assertIn("check-agent-rules", hook)
        self.assertIn("skill-quality/scripts/validate.py", hook)
        self.assertIn('stages = [ "pre-commit" ]', hook)

        self.assertIn("omp-thin-harness = {", flake)
        self.assertIn(r"config/codex/config\\.toml", flake)
        self.assertIn(r"prompts/thread-introspection\\.md", flake)
        self.assertIn("modules/agents/(codex|omp|plannotator)", flake)
        self.assertIn("tests/test_agent_response_contract.py", flake)
        self.assertIn("tests/test_codex_model_config.py", flake)
        self.assertIn("tests/test_omp_ttsr_rules.py", flake)
        self.assertIn(r"config/agents/core\\.md", flake)


if __name__ == "__main__":
    unittest.main()
