import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "bin" / "check-agent-rules"


class AgentRuleTests(unittest.TestCase):
    def run_checker(self, rules: Path, json_output: bool = False) -> subprocess.CompletedProcess[str]:
        command = [sys.executable, str(CHECKER)]
        if json_output:
            command.append("--json")
        command.append(str(rules))
        return subprocess.run(command, text=True, capture_output=True, check=False)

    def write_rule(
        self,
        directory: Path,
        filename: str = "01-example.md",
        rule_id: str = "AGENT-01",
        severity: str = "warn",
    ) -> Path:
        path = directory / filename
        path.write_text(
            "---\n"
            "purpose: Exercise the rule checker.\n"
            f"rule_id: {rule_id}\n"
            "enforced_by: prompt\n"
            f"severity: {severity}\n"
            f"waiver_path: .agents/waivers/{rule_id}.md\n"
            "---\n\n"
            "# Example\n\n"
            "Follow the example.\n"
        )
        return path

    def test_accepts_valid_rules_and_emits_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rules = Path(tmp)
            self.write_rule(rules)
            result = self.run_checker(rules, json_output=True)

        self.assertEqual(result.returncode, 0, result.stderr)
        summary = json.loads(result.stdout)
        self.assertEqual(summary["checked"], 1)
        self.assertEqual(summary["findings"], [])

    def test_rejects_rule_id_that_disagrees_with_filename(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rules = Path(tmp)
            self.write_rule(rules, rule_id="AGENT-02")
            result = self.run_checker(rules)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must match filename", result.stdout)

    def test_rejects_unknown_severity(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rules = Path(tmp)
            self.write_rule(rules, severity="urgent")
            result = self.run_checker(rules)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("severity", result.stdout)

    def test_rejects_duplicate_rule_ids(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rules = Path(tmp)
            self.write_rule(rules)
            self.write_rule(rules, filename="02-other.md", rule_id="AGENT-01")
            result = self.run_checker(rules)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate rule_id", result.stdout)

    def test_repository_rules_pass(self) -> None:
        result = self.run_checker(ROOT / "config" / "agents" / "rules")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
