import json
import os
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = json.loads((ROOT / "tests/fixtures/omp-ttsr-rules.json").read_text())
OMP_BIN = os.environ.get("OMP_BIN", "omp")


class OmpTtsrRuleTests(unittest.TestCase):
    def matched_rules(self, rule_path: str, snippet: str) -> list[str]:
        result = subprocess.run(
            [
                OMP_BIN,
                "ttsr",
                "test",
                "--rule",
                str(ROOT / rule_path),
                "--source",
                "tool",
                "--tool",
                "bash",
                "--json",
                snippet,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        payload = json.loads(result.stdout)
        return [item["name"] for item in payload["triggered"]]

    def test_local_ttsr_rules_match_only_their_named_scenarios(self) -> None:
        for rule_name, scenario in SCENARIOS.items():
            for snippet in scenario["positive"]:
                with self.subTest(rule=rule_name, expected="match", snippet=snippet):
                    self.assertEqual(
                        [rule_name],
                        self.matched_rules(scenario["rule"], snippet),
                    )

            for snippet in scenario["negative"]:
                with self.subTest(rule=rule_name, expected="no-match", snippet=snippet):
                    self.assertEqual([], self.matched_rules(scenario["rule"], snippet))

    def test_ci_watch_is_a_non_interrupting_tool_reminder(self) -> None:
        rule = (ROOT / SCENARIOS["ci-watch"]["rule"]).read_text()

        self.assertIn('scope: "tool:bash"', rule)
        self.assertIn('interruptMode: "never"', rule)
        self.assertNotIn("alwaysApply: true", rule)


if __name__ == "__main__":
    unittest.main()
