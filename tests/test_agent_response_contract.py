import json
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AgentResponseContractTests(unittest.TestCase):
    def test_shared_rule_is_action_first_and_bounded(self) -> None:
        rule = (ROOT / "config/agents/rules/01-tone-and-style.md").read_text()

        for expected in (
            "Be concise, direct, and candid",
            "distinguish verified facts from uncertainty",
            "Lead with the answer or next action.",
            "Number multi-step instructions",
            "State errors as cause, evidence, and fix.",
            "without noisy progress",
            "Make completed work visible.",
            "Cap lists at five items",
        ):
            self.assertIn(expected, rule)

    def test_shared_behavior_rule_requires_evidence_and_real_validation(self) -> None:
        rule = (ROOT / "config/agents/rules/15-agent-behavior.md").read_text()

        for expected in (
            "materially ambiguous, risky, or requires approval",
            "Use Visualize when a visual materially improves an explanation",
            "Spawn subagents only for genuinely independent work",
            "Ground research in authoritative, current sources",
            "validate user-facing work in the real interface when applicable",
        ):
            self.assertIn(expected, rule)

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

    def test_code_standards_scope_compatibility_and_dependency_choices(self) -> None:
        rule = (ROOT / "config/agents/rules/10-code-standards.md").read_text()

        for expected in (
            "Preserve backward compatibility only when required by documented consumers, public APIs, or migrations.",
            "Prefer established, well-maintained libraries when they materially reduce complexity; avoid dependencies for trivial behavior.",
        ):
            self.assertIn(expected, rule)

    def test_shared_version_control_rule_routes_work_through_herdr_jj_omp(self) -> None:
        rule = (ROOT / "config/agents/rules/03-version-control.md").read_text()

        for expected in (
            "Herdr owns task-workspace creation",
            "`prefix+a`",
            "the new workspace opens with OMP focused",
            "`jj root --ignore-working-copy`",
            "never initialize jj inside a Codex Desktop Git worktree",
            "use `done` for publication and cleanup",
            "record the task with `hey agent-start` without `--workspace`",
            "`jj diff --git -r @`",
        ):
            self.assertIn(expected, rule)

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


if __name__ == "__main__":
    unittest.main()
