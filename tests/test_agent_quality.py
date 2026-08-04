import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "agent-quality"
HEY_WRAPPER = ROOT / "bin" / "hey.d" / "agent-quality.nu"
HEY_FLAKE = ROOT / "bin" / "hey.d" / "flake.nu"
FLAKE = ROOT / "flake.nix"
OMP_MODULE = ROOT / "modules" / "agents" / "omp" / "default.nix"
AUTONOMOUS_RULE = ROOT / "config" / "agents" / "rules" / "16-autonomous-goal-progress.md"
AUTONOMOUS_SKILL = ROOT / "skills" / "catalog" / "autonomous-agent-loop" / "SKILL.md"
GOALIZE_PROMPT = ROOT / "config" / "pi" / "prompts" / "goalize.md"
GOAL_AUDIT_PROMPT = ROOT / "config" / "pi" / "prompts" / "goal-continue-audit.md"
DONE_SKILL = ROOT / "skills" / "catalog" / "done" / "SKILL.md"


class AgentQualityTests(unittest.TestCase):
    def git_only_env(self, root: Path) -> dict[str, str]:
        bin_dir = root / "bin"
        bin_dir.mkdir()
        git_path = shutil.which("git")
        self.assertIsNotNone(git_path)
        (bin_dir / "git").symlink_to(git_path)
        return os.environ | {"PATH": str(bin_dir)}

    def run_cli(
        self,
        *args: str,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=cwd or ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_inventory_check_matches_generated_document(self) -> None:
        result = self.run_cli("inventory", "--check")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_hey_uses_the_packaged_agent_quality_command(self) -> None:
        wrapper = HEY_WRAPPER.read_text()
        self.assertIn("^agent-quality ...$args", wrapper)
        self.assertNotIn("python3 bin/agent-quality", wrapper)

    def test_hey_and_git_hooks_use_the_nix_owned_prek_config(self) -> None:
        flake = FLAKE.read_text()
        hey = HEY_FLAKE.read_text()

        self.assertIn(
            "packages.pre-commit-config = config.pre-commit.settings.configFile;",
            flake,
        )
        self.assertIn("install.enable = false;", flake)
        self.assertIn(
            "--config ${config.pre-commit.settings.configFile}",
            flake,
        )
        self.assertIn(".#pre-commit-config", hey)
        self.assertEqual(hey.count("--config $precommit_config"), 2)

    def test_packaged_agent_quality_uses_the_active_checkout_and_jujutsu(self) -> None:
        wrapper = HEY_WRAPPER.read_text()
        module = OMP_MODULE.read_text()

        self.assertIn("let ctx = (context)", wrapper)
        self.assertIn("AGENT_QUALITY_ROOT: $ctx.flake_dir", wrapper)
        self.assertIn("pkgs.jujutsu", module)
        self.assertNotIn("pkgs.jj", module)
        self.assertIn(
            'export AGENT_QUALITY_ROOT="\'\'${AGENT_QUALITY_ROOT:-${../../..}}"',
            module,
        )

    def test_completion_contract_stays_aligned_across_canonical_sources(self) -> None:
        sources = {
            "shared rule": AUTONOMOUS_RULE.read_text(),
            "autonomous loop skill": AUTONOMOUS_SKILL.read_text(),
            "goalize prompt": GOALIZE_PROMPT.read_text(),
            "goal audit prompt": GOAL_AUDIT_PROMPT.read_text(),
        }

        for name, source in sources.items():
            with self.subTest(source=name):
                self.assertIn("one active", source)
                self.assertIn("parked", source.lower())
                self.assertIn("blocked", source.lower())
                self.assertIn("evidence", source.lower())

        for source in ("shared rule", "autonomous loop skill", "goalize prompt"):
            with self.subTest(contract=source):
                self.assertIn("`Outcome`", sources[source])
                self.assertIn("`Done when`", sources[source])
                self.assertIn("`Proof`", sources[source])

        audit = sources["goal audit prompt"]
        for state in ("`verified`", "`unverified`", "`parked`", "`blocked`"):
            self.assertIn(state, audit)
        self.assertIn("Continue unless", audit)
        self.assertIn("planning or passing local checks alone is not completion", audit)

    def test_done_skill_preserves_landing_safety_contract(self) -> None:
        done_skill = DONE_SKILL.read_text()

        self.assertIn("### Dirty default checkout integration", done_skill)
        self.assertIn("temporary integration worktree", done_skill)
        self.assertIn("merge --ff-only", done_skill)
        self.assertIn(
            "Never report `done` from a clean feature workspace alone.",
            done_skill,
        )

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
            test.write_text(
                'test("skips empty values", () => { expect([]).toEqual([]); });\n'
            )
            result = self.run_cli("audit-tests", str(root))
            self.assertEqual(result.returncode, 0, result.stdout)

    def test_test_audit_accepts_unittest_assert_true_methods(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            test = root / "test_behavior.py"
            test.write_text(
                "import unittest\n\n"
                "class BehaviorTest(unittest.TestCase):\n"
                "    def test_behavior(self):\n"
                "        self.assertTrue(subject())\n"
            )
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

    def test_start_writes_a_git_receipt_without_jj_installed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            state = root / "state"
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)

            result = self.run_cli(
                "start",
                "--repo",
                str(repo),
                "--task",
                "demo-task",
                "--runtime",
                "codex",
                "--model",
                "gpt-5",
                "--state-dir",
                str(state),
                env=self.git_only_env(root),
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["schemaVersion"], 1)
            self.assertEqual(receipt["backend"], "git")
            self.assertEqual(receipt["task"], "demo-task")
            self.assertEqual(receipt["status"], "active")
            self.assertEqual(receipt["metrics"], {"retries": 0, "userCorrections": 0})
            self.assertTrue(Path(receipt["receiptPath"]).is_file())

    @unittest.skipUnless(shutil.which("jj"), "jj is not installed")
    def test_start_creates_an_isolated_jj_workspace_and_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            # Nix Python may return /tmp on macOS while jj canonicalizes it to /private/tmp.
            root = Path(tmp).resolve()
            repo = root / "repo"
            workspace = root / "workspaces" / "demo"
            state = root / "state"
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
            subprocess.run(
                ["jj", "git", "init", "--colocate", str(repo)],
                check=True,
                capture_output=True,
                text=True,
            )

            result = self.run_cli(
                "start",
                "--repo",
                str(repo),
                "--workspace",
                str(workspace),
                "--task",
                "jj-demo",
                "--runtime",
                "pi",
                "--state-dir",
                str(state),
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["backend"], "jj")
            self.assertEqual(Path(receipt["workspaceRoot"]), workspace.resolve())
            self.assertTrue((workspace / ".jj").exists())
            self.assertTrue(receipt["vcs"]["changeId"])
            self.assertTrue(receipt["vcs"]["operationId"])

    def test_start_refuses_to_invent_jj_inside_a_git_worktree_without_jj(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            worktree = root / "worktree"
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(repo),
                    "config",
                    "user.email",
                    "test@example.invalid",
                ],
                check=True,
            )
            subprocess.run(
                ["git", "-C", str(repo), "config", "user.name", "Test"], check=True
            )
            (repo / "base.txt").write_text("base\n")
            subprocess.run(["git", "-C", str(repo), "add", "base.txt"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-m", "base"], check=True)
            subprocess.run(
                ["git", "-C", str(repo), "worktree", "add", str(worktree)], check=True
            )

            result = self.run_cli(
                "start",
                "--repo",
                str(worktree),
                "--workspace",
                str(root / "jj-workspace"),
                "--task",
                "boundary",
                "--state-dir",
                str(root / "state"),
                env=self.git_only_env(root),
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("Git worktree", result.stderr)
            self.assertIn("initialize jj from the primary checkout", result.stderr)

    def test_complete_and_sweep_report_false_done_signals(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            receipt = root / "run.json"
            receipt.write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "runId": "run-1",
                        "task": "demo",
                        "backend": "jj",
                        "status": "active",
                        "startedAt": "2026-07-19T10:00:00Z",
                        "metrics": {"retries": 0, "userCorrections": 0},
                    }
                )
            )

            completed = self.run_cli(
                "complete",
                str(receipt),
                "--local-tip",
                "abc",
                "--remote-tip",
                "def",
                "--retries",
                "2",
                "--user-corrections",
                "1",
            )
            self.assertEqual(completed.returncode, 1)
            updated = json.loads(receipt.read_text())
            self.assertEqual(updated["status"], "false_done")
            self.assertFalse(updated["landing"]["remoteAligned"])

            swept = self.run_cli(
                "sweep", "--state-dir", str(root), "--since-days", "36500", "--json"
            )
            self.assertEqual(swept.returncode, 1)
            summary = json.loads(swept.stdout)
            self.assertEqual(summary["runs"], 1)
            self.assertEqual(summary["falseDone"], 1)
            self.assertEqual(summary["retries"], 2)
            self.assertEqual(summary["userCorrections"], 1)


if __name__ == "__main__":
    unittest.main()
