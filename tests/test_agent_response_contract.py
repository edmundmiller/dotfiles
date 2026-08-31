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

    def test_agent_quality_gate_runs_the_response_contract(self) -> None:
        manifest = json.loads((ROOT / ".agents/quality.json").read_text())
        check = next(
            item for item in manifest["checks"] if item["id"] == "agent-quality-tests"
        )

        self.assertIn("tests/test_agent_response_contract.py", check["command"])

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

    def test_pi_makes_summary_budget_and_verbosity_control_explicit(self) -> None:
        settings = (ROOT / "config/pi/settings.jsonc").read_text()

        self.assertRegex(
            settings,
            r'"branchSummary"\s*:\s*\{\s*"reserveTokens"\s*:\s*16384',
        )
        self.assertIn('"npm:pi-verbosity-control"', settings)

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
