import json
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AgentResponseContractTests(unittest.TestCase):
    def test_thin_core_is_action_first_and_bounded(self) -> None:
        core = (ROOT / "config/agents/core.md").read_text()
        normalized = " ".join(core.split())

        self.assertLessEqual(len(core.split()), 220)
        for expected in (
            "Communicate concisely",
            "lead with the outcome",
            "separate evidence from uncertainty",
            "state blockers with the smallest action that resolves them",
        ):
            self.assertIn(expected, normalized)

    def test_repository_checks_run_the_response_contract(self) -> None:
        flake = (ROOT / "flake.nix").read_text()

        self.assertIn("agent-response-contract =", flake)
        self.assertIn("tests/test_agent_response_contract.py", flake)

    def test_codex_bootstrap_instructions_stay_bounded(self) -> None:
        config = tomllib.loads((ROOT / "config/codex/config.toml").read_text())
        instructions = config["developer_instructions"]

        self.assertLessEqual(len(instructions.split()), 150)
        self.assertNotIn("READY_FOR_DONE", instructions)
        self.assertNotIn("Durable goals are checkpoints", instructions)
        self.assertIn("Keep Sol as the primary coordinator", instructions)

    def test_thin_core_requires_scope_authority_and_live_evidence(self) -> None:
        core = (ROOT / "config/agents/core.md").read_text()

        for expected in (
            "Preserve unrelated work",
            "Do not infer authority",
            "Inspect the live source of truth before acting",
            "Do not claim completion without fresh evidence",
        ):
            self.assertIn(expected, core)

    def test_codex_defaults_keep_responses_and_reasoning_summaries_concise(self) -> None:
        config = tomllib.loads((ROOT / "config/codex/config.toml").read_text())

        self.assertEqual(config["personality"], "pragmatic")
        self.assertEqual(config["model_verbosity"], "low")
        self.assertEqual(config["model_reasoning_summary"], "concise")

    def test_pi_uses_native_defaults_without_automatic_coaching(self) -> None:
        settings = (ROOT / "config/pi/settings.jsonc").read_text()

        for key in (
            "branchSummary", "compaction", "retry", "steeringMode",
            "followUpMode", "images", "enableSkillCommands",
        ):
            with self.subTest(key=key):
                self.assertNotRegex(settings, rf'"{key}"\s*:')
        for package in (
            "npm:pi-verbosity-control", "npm:pi-rtk", "npm:pi-model-switch",
            "git:github.com/edmundmiller/pi-codex-goal",
            "~/.config/dotfiles/packages/pi-packages/pi-dcp",
            "~/.config/dotfiles/packages/pi-packages/pi-agentmap",
        ):
            with self.subTest(package=package):
                self.assertNotIn(json.dumps(package), settings)

    def test_pi_retains_safety_and_useful_integrations(self) -> None:
        settings = (ROOT / "config/pi/settings.jsonc").read_text()
        for package in (
            "npm:@gotgenes/pi-permission-system",
            "~/.pi/agent/packages/pi-command-policy-bridge",
            "npm:pi-hermes-memory", "npm:pi-terminal-theme",
            "npm:pi-agent-browser-native",
        ):
            with self.subTest(package=package):
                self.assertIn(json.dumps(package), settings)
        links = (ROOT / "modules/agents/pi/lib/_home-files.nix").read_text()
        self.assertIn("enforce-commit-signing.ts", links)
        self.assertNotIn("you-are-right-killer.ts", links)

    def test_goalize_does_not_require_a_goal_service(self) -> None:
        prompt = (ROOT / "config/pi/prompts/goalize.md").read_text()
        for field in ("`Outcome`", "`Done when`", "`Proof`", "$ARGUMENTS"):
            self.assertIn(field, prompt)
        self.assertNotIn("pi-codex-goal", prompt)
        self.assertNotIn("Create exactly one active goal", prompt)
        self.assertIn("planning does not authorize implementation", prompt)

    def test_typescript_any_policy_is_enforced_by_lint(self) -> None:
        lint = (ROOT / "bin/lint-ts-architecture").read_text()

        self.assertIn("ban `as any` outside test files", lint)
        self.assertIn("'as any' is forbidden outside tests", lint)

    def test_version_control_procedure_lives_in_selective_workflows(self) -> None:
        workflow = (ROOT / "AGENT_WORKFLOW.md").read_text()
        workspace_skill = (
            ROOT / ".agents/skills/using-jj-workspaces/SKILL.md"
        ).read_text()
        done_skill = (ROOT / "skills/catalog/done/SKILL.md").read_text()

        self.assertIn("If Herdr already created the current jj task workspace", workflow)
        for expected in ("`prefix+a`", "jj root --ignore-working-copy", "hey agent-start"):
            self.assertIn(expected, workspace_skill)
        self.assertIn("jj diff --git -r @", workspace_skill)
        self.assertIn("Run `jj root --ignore-working-copy`", done_skill)

    def test_omp_jj_rule_triggers_at_herdr_decision_points(self) -> None:
        rule = (ROOT / "config/omp/rules/working-with-jj.md").read_text()
        condition_line = next(
            line for line in rule.splitlines() if line.startswith("condition: ")
        )
        condition = json.loads(condition_line.removeprefix("condition: "))

        for command in (
            "HERDR_ENV=1 hey agent-start --repo . --task demo",
            "herdr agent list",
            "hunk diff",
            "jj status",
            "git commit -m demo",
        ):
            with self.subTest(command=command):
                self.assertRegex(command, condition)

        self.assertNotRegex("git status", condition)

    def test_thin_core_keeps_a_compact_response_contract(self) -> None:
        core = (ROOT / "config/agents/core.md").read_text()
        normalized = " ".join(core.split())

        self.assertLessEqual(len(core.split()), 220)
        for expected in (
            "Communicate concisely",
            "lead with the outcome",
            "separate evidence from uncertainty",
            "state blockers with the smallest action that resolves them",
        ):
            self.assertIn(expected, normalized)


if __name__ == "__main__":
    unittest.main()
