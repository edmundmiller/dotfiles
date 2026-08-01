import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AgentResponseContractTests(unittest.TestCase):
    def test_shared_rule_is_action_first_and_bounded(self) -> None:
        rule = (ROOT / "config/agents/rules/01-tone-and-style.md").read_text()

        for expected in (
            "Lead with the answer or next action.",
            "Number multi-step instructions",
            "State errors as cause, evidence, and fix.",
            "Make completed work visible.",
            "Cap lists at five items",
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

    def test_shared_version_control_rule_routes_codex_through_herdr_jj(self) -> None:
        rule = (ROOT / "config/agents/rules/03-version-control.md").read_text()

        for expected in (
            "Herdr owns jj workspace creation",
            "`prefix+a`",
            "Codex",
            "`jj root --ignore-working-copy`",
            "Never initialize jj inside a Codex Desktop Git worktree",
            "Use the `done` skill",
        ):
            self.assertIn(expected, rule)

    def test_code_standards_scope_compatibility_and_dependency_choices(self) -> None:
        rule = (ROOT / "config/agents/rules/10-code-standards.md").read_text()

        for expected in (
            "Preserve backward compatibility only when required by documented consumers, public APIs, or migrations.",
            "Prefer established, well-maintained libraries when they materially reduce complexity; avoid dependencies for trivial behavior.",
        ):
            self.assertIn(expected, rule)


if __name__ == "__main__":
    unittest.main()
