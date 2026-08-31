import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "agent-run"
HEY_WRAPPER = ROOT / "bin" / "hey.d" / "agent-run.nu"
HEY_FLAKE = ROOT / "bin" / "hey.d" / "flake.nu"
FLAKE = ROOT / "flake.nix"
ORB_SETUP = ROOT / ".agents" / "setup"
AGENT_WORKFLOW = ROOT / "AGENT_WORKFLOW.md"
OMP_MODULE = ROOT / "modules" / "agents" / "omp" / "default.nix"
OMP_GO_COMMAND = ROOT / "config" / "omp" / "commands" / "go.md"
CODEX_CONFIG = ROOT / "config" / "codex" / "config.toml"
LUNA_PROFILE = ROOT / "config" / "codex" / "agents" / "luna_worker.toml"
AUTONOMOUS_SKILL = ROOT / "skills" / "catalog" / "autonomous-agent-loop" / "SKILL.md"
GOALIZE_PROMPT = ROOT / "config" / "pi" / "prompts" / "goalize.md"
GOAL_AUDIT_PROMPT = ROOT / "config" / "pi" / "prompts" / "goal-continue-audit.md"
DONE_SKILL = ROOT / "skills" / "catalog" / "done" / "SKILL.md"


class AgentRunTests(unittest.TestCase):
    def setUp(self) -> None:
        signing = patch.dict(
            os.environ,
            {
                "GIT_CONFIG_COUNT": "1",
                "GIT_CONFIG_KEY_0": "commit.gpgsign",
                "GIT_CONFIG_VALUE_0": "false",
            },
        )
        signing.start()
        self.addCleanup(signing.stop)

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

    def test_hey_uses_the_packaged_agent_run_command(self) -> None:
        wrapper = HEY_WRAPPER.read_text()
        self.assertIn("^agent-run ...$args", wrapper)
        self.assertNotIn("python3 bin/agent-run", wrapper)

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
        self.assertEqual(hey.count("--config $precommit_config"), 4)
        self.assertIn("actionlint = {", flake)
        self.assertIn("agent-run-tests =", flake)

    def test_repository_oxlint_loads_anti_slop_without_package_configs(self) -> None:
        flake = FLAKE.read_text()
        setup = ORB_SETUP.read_text()

        self.assertIn(
            'entry = "${antiSlopOxlint}/bin/oxlint --threads=1 --quiet --disable-nested-config --config ${antiSlopConfig}";',
            flake,
        )
        self.assertIn("sudo sysctl -w vm.overcommit_memory=1", setup)
        self.assertIn('url = "github:dmmulroy/anti-slop";', flake)
        self.assertIn('"anti-slop/no-chained-type-assertions" = "error";', flake)
        self.assertIn(
            '"anti-slop/require-safety-comment-for-type-assertion" = "error";',
            flake,
        )

    def test_orb_setup_limits_nix_parallelism(self) -> None:
        setup = ORB_SETUP.read_text()

        self.assertIn('"eval-cores = 1"', setup)
        self.assertIn('"max-jobs = 1"', setup)
        self.assertIn('"cores = 1"', setup)
        self.assertIn('swapfile="/swapfile"', setup)
        self.assertIn('sudo fallocate -l 4G "$swapfile"', setup)
        self.assertIn('sudo /usr/sbin/swapon "$swapfile"', setup)

    def test_packaged_agent_run_is_receipt_only_and_repo_explicit(self) -> None:
        wrapper = HEY_WRAPPER.read_text()
        module = OMP_MODULE.read_text()

        self.assertNotIn("context", wrapper)
        self.assertNotIn("AGENT_RUN_ROOT", wrapper + module)
        self.assertNotIn("agent-review", wrapper)
        self.assertNotIn("agent-worklog-check", wrapper)
        self.assertIn("pkgs.jujutsu", module)
        self.assertNotIn("pkgs.jj", module)
        self.assertIn("exec python3 ${../../../bin/agent-run}", module)

    def test_completion_contract_stays_aligned_across_canonical_sources(self) -> None:
        sources = {
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

        for source in ("autonomous loop skill", "goalize prompt"):
            with self.subTest(contract=source):
                self.assertIn("`Outcome`", sources[source])
                self.assertIn("`Done when`", sources[source])
                self.assertIn("`Proof`", sources[source])

        audit = sources["goal audit prompt"]
        for state in ("`verified`", "`unverified`", "`parked`", "`blocked`"):
            self.assertIn(state, audit)
        self.assertIn("Continue unless", audit)
        self.assertIn("planning or passing local checks alone is not completion", audit)

    def test_return_and_land_contract_lives_on_selective_goal_surfaces(self) -> None:
        sources = {
            "worker": LUNA_PROFILE.read_text(),
            "autonomous loop skill": AUTONOMOUS_SKILL.read_text(),
        }

        for name, source in sources.items():
            with self.subTest(source=name):
                for token in ("CONTINUE", "PARTIAL", "LANDED", "BLOCKED"):
                    self.assertIn(token, source)

        worker = sources["worker"]
        for field in (
            "status",
            "changed_paths",
            "verification",
            "landing_state",
            "next_action",
        ):
            with self.subTest(field=field):
                self.assertIn(field, worker)

        primary = CODEX_CONFIG.read_text().lower()
        for phrase in (
            "worker reports as claims",
            "waits for workers",
            "requested outcome is complete",
        ):
            self.assertIn(phrase, primary)

        for detail in (
            "continue",
            "partial",
            "landed",
            "blocked",
            "structured",
            "durable goals are checkpoints",
        ):
            self.assertNotIn(detail, primary)

    def test_self_improvement_routes_away_from_shared_rule_bundles(self) -> None:
        skill = AUTONOMOUS_SKILL.read_text()

        self.assertNotIn("shared rules", skill.lower())
        for destination in ("`AGENTS.md`", "existing skill", "prompt template", "repo doc"):
            self.assertIn(destination, skill)

    def test_omp_go_command_requires_parent_worker_return_and_landing_contract(self) -> None:
        command = OMP_GO_COMMAND.read_text().lower()

        for phrase in (
            "wait for every worker",
            "structured return envelope",
            "landing proof",
            "keep the issue open through `done`",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, command)

        for field in (
            "status",
            "changed_paths",
            "verification",
            "landing_state",
            "next_action",
        ):
            with self.subTest(field=field):
                self.assertIn(field, command)

        for state in ("continue", "partial", "landed", "blocked"):
            with self.subTest(state=state):
                self.assertIn(state, command)

    def test_return_contract_uses_structured_wording_without_machine_readable_claims(self) -> None:
        sources = {
            "worker": LUNA_PROFILE.read_text(),
            "autonomous loop skill": AUTONOMOUS_SKILL.read_text(),
            "omp go command": OMP_GO_COMMAND.read_text(),
        }

        for name, source in sources.items():
            with self.subTest(source=name):
                normalized = source.lower()
                self.assertNotIn("machine-readable", normalized)
                self.assertIn("structured", normalized)

        primary = CODEX_CONFIG.read_text().lower()
        self.assertNotIn("machine-readable", primary)
        self.assertNotIn("structured", primary)

    def test_done_skill_preserves_landing_safety_contract(self) -> None:
        references = DONE_SKILL.parent / "references"
        done_skill = (
            DONE_SKILL.read_text()
            + "\n"
            + "\n".join(path.read_text() for path in sorted(references.glob("*.md")))
        )

        self.assertIn("## Dirty default checkout integration", done_skill)
        self.assertIn("temporary integration worktree", done_skill)
        self.assertIn("merge --ff-only", done_skill)
        self.assertIn(
            "A clean feature workspace, successful",
            done_skill,
        )

    def test_cross_model_review_is_opt_in(self) -> None:
        workflow = AGENT_WORKFLOW.read_text()

        self.assertIn("Cross-model review is optional", workflow)
        self.assertNotIn("hey agent-review plan", workflow)
        self.assertNotIn("hey agent-review landing", workflow)

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
            self.assertEqual(receipt["schemaVersion"], 2)
            self.assertEqual(receipt["backend"], "git")
            self.assertEqual(receipt["task"], "demo-task")
            self.assertEqual(receipt["status"], "active")
            self.assertEqual(receipt["closeout"]["status"], "active")
            self.assertFalse(receipt["provenance"]["lateAdopted"])
            self.assertEqual(
                receipt["provenance"]["startRevision"], receipt["vcs"]["commitId"]
            )
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

    def test_checkpoint_keeps_partial_v2_receipt_open(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            receipt = root / "run.json"
            evidence = root / "evidence.txt"
            receipt.write_text(
                json.dumps(
                    {
                        "schemaVersion": 2,
                        "runId": "run-2",
                        "task": "demo",
                        "backend": "git",
                        "status": "active",
                        "startedAt": "2026-08-15T10:00:00Z",
                        "metrics": {"retries": 0, "userCorrections": 0},
                        "closeout": {"status": "active"},
                    }
                )
            )
            evidence.write_text(json.dumps({"localTip": "abc", "remoteTip": "abc"}))

            result = self.run_cli(
                "checkpoint",
                str(receipt),
                "--outcome",
                "landed_cleanup_deferred",
                "--task-revision",
                "task-1",
                "--evidence-json",
                str(evidence),
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            updated = json.loads(receipt.read_text())
            self.assertEqual(updated["status"], "active")
            self.assertEqual(updated["closeout"]["status"], "landed_cleanup_deferred")
            self.assertEqual(updated["closeout"]["taskRevisions"], ["task-1"])
            self.assertNotIn("completedAt", updated)

            swept = self.run_cli(
                "sweep", "--state-dir", str(root), "--since-days", "36500", "--json"
            )
            self.assertEqual(swept.returncode, 0, swept.stderr)
            summary = json.loads(swept.stdout)
            self.assertEqual(summary["active"], 1)
            self.assertEqual(summary["closeoutStatuses"]["landed_cleanup_deferred"], 1)

    def test_adopt_creates_late_v2_receipt_with_explicit_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            state = root / "state"
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
            subprocess.run(
                ["git", "-C", str(repo), "config", "user.name", "Test"], check=True
            )
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
            (repo / "state.txt").write_text("base\n")
            subprocess.run(["git", "-C", str(repo), "add", "state.txt"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-m", "base"], check=True)
            revision = subprocess.run(
                ["git", "-C", str(repo), "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()

            result = self.run_cli(
                "adopt",
                "--repo",
                str(repo),
                "--task",
                "late-task",
                "--start-revision",
                revision,
                "--task-revision",
                revision,
                "--authority",
                "verify",
                "--state-dir",
                str(state),
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["schemaVersion"], 2)
            self.assertTrue(receipt["provenance"]["lateAdopted"])
            self.assertEqual(receipt["provenance"]["startRevision"], revision)
            self.assertEqual(receipt["closeout"]["taskRevisions"], [revision])
            self.assertEqual(receipt["authority"]["mode"], "verify")

            invalid = self.run_cli(
                "adopt",
                "--repo",
                str(repo),
                "--task",
                "late-task",
                "--start-revision",
                revision,
                "--task-revision",
                "missing-task-revision",
                "--state-dir",
                str(state),
            )
            self.assertEqual(invalid.returncode, 2)
            self.assertIn("task revision is not valid", invalid.stderr)

    def test_v2_done_local_completes_without_inventing_a_remote_tip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            receipt = Path(tmp) / "run.json"
            receipt.write_text(
                json.dumps(
                    {
                        "schemaVersion": 2,
                        "runId": "run-local",
                        "task": "local-task",
                        "backend": "git",
                        "status": "active",
                        "startedAt": "2026-08-15T10:00:00Z",
                        "metrics": {"retries": 0, "userCorrections": 0},
                        "closeout": {"status": "active", "taskRevisions": []},
                    }
                )
            )

            result = self.run_cli(
                "complete",
                str(receipt),
                "--outcome",
                "done_local",
                "--local-tip",
                "abc",
                "--task-revision",
                "task-1",
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            updated = json.loads(receipt.read_text())
            self.assertEqual(updated["status"], "complete")
            self.assertEqual(updated["closeout"]["status"], "done_local")
            self.assertIsNone(updated["landing"]["remoteTip"])


if __name__ == "__main__":
    unittest.main()
