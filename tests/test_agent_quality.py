import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "agent-quality"


class AgentQualityTests(unittest.TestCase):
    def run_cli(self, *args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=cwd or ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_inventory_check_matches_generated_document(self) -> None:
        result = self.run_cli("inventory", "--check")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_worklog_validation_accepts_complete_log(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "worklog.md"
            log.write_text(
                "# Worklog: demo\n\n"
                "Status: complete\n\n"
                "## Objective\nDone.\n\n"
                "## Decisions\nNone.\n\n"
                "## Evidence\nTests pass.\n\n"
                "## Reviews\nPlan and landing reviewed.\n\n"
                "## Feedback\nNo workflow feedback.\n\n"
                "## Remaining work\nNone.\n\n"
                "## Commits\nabc123.\n"
            )
            result = self.run_cli("validate-worklog", str(log))
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_worklog_validation_rejects_missing_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "worklog.md"
            log.write_text("# Worklog: demo\n\nStatus: active\n")
            result = self.run_cli("validate-worklog", str(log))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Evidence", result.stderr)

    def test_test_audit_flags_vacuous_python_test(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            test = root / "test_empty.py"
            test.write_text("def test_nothing():\n    pass\n")
            result = self.run_cli("audit-tests", str(root))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("empty test body", result.stdout)

    def test_test_audit_ignores_skip_word_in_test_description(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            test = root / "behavior.test.ts"
            test.write_text('test("skips empty values", () => { expect([]).toEqual([]); });\n')
            result = self.run_cli("audit-tests", str(root))
            self.assertEqual(result.returncode, 0, result.stdout)

    def test_test_audit_ignores_dependency_tests(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dependency = root / "node_modules" / "package"
            dependency.mkdir(parents=True)
            (dependency / "broken.test.ts").write_text(
                "test('x', () => expect(" + "true));\n"
            )
            (root / "behavior.test.ts").write_text(
                "test('works', () => { expect(value()).toEqual(1); });\n"
            )
            result = self.run_cli("audit-tests", str(root))
            self.assertEqual(result.returncode, 0, result.stdout)


    def test_finish_reports_inapplicable_checks_without_calling_them_passed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "quality.json"
            manifest.write_text(
                json.dumps(
                    {
                        "checks": [
                            {
                                "id": "visual",
                                "kind": "visual",
                                "command": "false",
                                "paths": ["ui/**"],
                            }
                        ]
                    }
                )
            )
            result = self.run_cli("finish", "--manifest", str(manifest), "--changed", "README.md")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("NOT_APPLICABLE visual", result.stdout)
            self.assertNotIn("PASS visual", result.stdout)

    def test_visual_compare_accepts_identical_png_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            baseline = root / "baseline"
            current = root / "current"
            baseline.mkdir()
            current.mkdir()
            (baseline / "page.png").write_bytes(b"same-png-fixture")
            (current / "page.png").write_bytes(b"same-png-fixture")
            result = self.run_cli("visual-compare", str(baseline), str(current))
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_review_rejects_same_model_family(self) -> None:
        result = self.run_cli(
            "review",
            "landing",
            "--active-model-family",
            "claude",
            "--reviewer",
            "claude",
            "--worklog",
            "worklog.md",
            "--dry-run",
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("different model family", result.stderr)


if __name__ == "__main__":
    unittest.main()
