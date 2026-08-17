import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLOSEOUT = ROOT / "skills/catalog/done/scripts/closeout.py"
PUBLISH_CLEAN = ROOT / "skills/catalog/done/scripts/publish-clean.py"


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


class DoneCloseoutTest(unittest.TestCase):
    def init_repo(self, root: Path) -> tuple[Path, Path]:
        remote = root / "remote.git"
        repo = root / "repo"
        subprocess.run(["git", "init", "--bare", str(remote)], check=True)
        subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
        git(repo, "config", "user.name", "Done Test")
        git(repo, "config", "user.email", "done@example.invalid")
        (repo / "base.txt").write_text("base\n")
        git(repo, "add", "base.txt")
        git(repo, "commit", "-m", "base")
        git(repo, "remote", "add", "origin", str(remote))
        git(repo, "push", "-u", "origin", "main")
        subprocess.run(
            ["git", "-C", str(remote), "symbolic-ref", "HEAD", "refs/heads/main"],
            check=True,
        )
        git(repo, "remote", "set-head", "origin", "-a")
        return repo, remote

    def run_closeout(self, *args: str, cwd: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(CLOSEOUT), *args],
            cwd=cwd,
            capture_output=True,
            text=True,
        )

    def run_publish_clean(
        self,
        *args: str,
        cwd: Path,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(PUBLISH_CLEAN), *args],
            cwd=cwd,
            capture_output=True,
            text=True,
            env=env,
        )

    def source_state(self, repo: Path) -> dict[str, object]:
        return {
            "head": git(repo, "rev-parse", "HEAD"),
            "branch": git(repo, "branch", "--show-current"),
            "status": git(repo, "status", "--porcelain=v1", "--untracked-files=all"),
            "cached": git(repo, "diff", "--cached", "--binary", "--no-ext-diff"),
            "unstaged": git(repo, "diff", "--binary", "--no-ext-diff"),
            "base": (repo / "base.txt").read_bytes(),
            "untracked": (repo / "untracked.txt").read_bytes(),
        }

    def create_task_revision(self, repo: Path, root: Path) -> tuple[Path, str]:
        task = root / "task"
        git(repo, "worktree", "add", "-b", "task", str(task), "main")
        (task / "task.txt").write_text("task\n")
        git(task, "add", "task.txt")
        git(task, "commit", "-m", "task")
        return task, git(task, "rev-parse", "HEAD")

    def test_snapshot_is_structured_secret_safe_and_repeatable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo, _ = self.init_repo(Path(tmp))
            secret = "not-for-output"
            (repo / "untracked.txt").write_text(secret)

            first = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            second = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            payload = json.loads(first.stdout)
            self.assertEqual(payload["schemaVersion"], 1)
            self.assertEqual(payload["backend"], "git")
            self.assertEqual(payload["destination"]["defaultBranch"], "main")
            self.assertEqual(payload["destination"]["remote"], "origin")
            self.assertFalse(payload["workingCopy"]["clean"])
            self.assertEqual(first.stdout, second.stdout)
            self.assertNotIn(secret, first.stdout)
            self.assertEqual(
                payload["workingCopy"]["untracked"][0]["path"], "untracked.txt"
            )

    def test_verify_preservation_detects_changed_unrelated_dirt(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            (repo / "untracked.txt").write_text("before\n")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            unchanged = self.run_closeout(
                "verify-preservation", "--snapshot", str(snapshot_path), cwd=repo
            )
            self.assertEqual(unchanged.returncode, 0, unchanged.stderr)

            (repo / "untracked.txt").write_text("after\n")
            changed = self.run_closeout(
                "verify-preservation", "--snapshot", str(snapshot_path), cwd=repo
            )
            self.assertEqual(changed.returncode, 1)
            self.assertIn("working-copy fingerprint changed", changed.stderr)

    def test_classify_blocks_unrelated_local_default_commits(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            base = git(repo, "rev-parse", "HEAD")
            (repo / "task.txt").write_text("task\n")
            git(repo, "add", "task.txt")
            git(repo, "commit", "-m", "task")
            task = git(repo, "rev-parse", "HEAD")
            (repo / "other.txt").write_text("other\n")
            git(repo, "add", "other.txt")
            git(repo, "commit", "-m", "other")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-base",
                base,
                "--task-revision",
                task,
                "--authority",
                "full",
                cwd=repo,
            )

            self.assertEqual(result.returncode, 1)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "blocked")
            self.assertEqual(len(payload["unrelatedLocalCommits"]), 1)
            self.assertIn("publication authority", payload["blockers"][0])

    def test_malformed_snapshot_is_unknown_not_a_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.json"
            path.write_text("not-json")
            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(path),
                "--task-revision",
                "x",
                cwd=Path(tmp),
            )

            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
            self.assertIn("cannot read snapshot", result.stderr)
            self.assertNotIn("Traceback", result.stderr)

    def test_classify_accepts_aggregate_patch_equivalent_squash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            base = git(repo, "rev-parse", "HEAD")
            git(repo, "switch", "-c", "task")
            (repo / "one.txt").write_text("one\n")
            git(repo, "add", "one.txt")
            git(repo, "commit", "-m", "one")
            one = git(repo, "rev-parse", "HEAD")
            (repo / "two.txt").write_text("two\n")
            git(repo, "add", "two.txt")
            git(repo, "commit", "-m", "two")
            two = git(repo, "rev-parse", "HEAD")
            git(repo, "switch", "main")
            git(repo, "merge", "--squash", "task")
            git(repo, "commit", "-m", "squashed task")
            landed = git(repo, "rev-parse", "HEAD")
            git(repo, "push", "origin", "main")
            git(repo, "switch", "task")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-base",
                base,
                "--task-revision",
                one,
                "--task-revision",
                two,
                "--landed-revision",
                landed,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "ready")
            self.assertEqual(payload["destination"]["defaultBranch"], "main")
            evidence = [
                item["evidence"] for item in json.loads(result.stdout)["taskRevisions"]
            ]
            self.assertEqual(evidence, ["aggregate-patch-equivalent"] * 2)

    def test_local_only_classification_uses_local_default_without_a_remote(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            subprocess.run(["git", "init", "-b", "main", str(repo)], check=True)
            git(repo, "config", "user.name", "Done Test")
            git(repo, "config", "user.email", "done@example.invalid")
            (repo / "base.txt").write_text("base\n")
            git(repo, "add", "base.txt")
            git(repo, "commit", "-m", "base")
            base = git(repo, "rev-parse", "HEAD")
            git(repo, "switch", "-c", "task")
            (repo / "task.txt").write_text("task\n")
            git(repo, "add", "task.txt")
            git(repo, "commit", "-m", "task")
            task = git(repo, "rev-parse", "HEAD")
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-base",
                base,
                "--task-revision",
                task,
                "--authority",
                "local-only",
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.expectedFailure
    def test_publish_clean_uses_authoritative_default_over_stale_cached_head(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)

            updater = root / "updater"
            git(root, "clone", str(remote), str(updater))
            git(updater, "config", "user.name", "Done Test")
            git(updater, "config", "user.email", "done@example.invalid")
            git(updater, "switch", "-c", "develop")
            (updater / "develop.txt").write_text("develop\n")
            git(updater, "add", "develop.txt")
            git(updater, "commit", "-m", "develop")
            git(updater, "push", "origin", "develop")
            git(remote, "symbolic-ref", "HEAD", "refs/heads/develop")
            self.assertEqual(
                "refs/remotes/origin/main",
                git(repo, "symbolic-ref", "refs/remotes/origin/HEAD"),
            )

            _, task_revision = self.create_task_revision(repo, root)
            before = self.source_state(repo)
            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual("develop", payload["defaultBranch"])
            self.assertEqual(before, self.source_state(repo))
            self.assertEqual(
                {"base.txt", "develop.txt", "task.txt"},
                set(git(remote, "ls-tree", "-r", "--name-only", "develop").splitlines()),
            )
            self.assertEqual(
                {"base.txt"},
                set(git(remote, "ls-tree", "-r", "--name-only", "main").splitlines()),
            )

    def test_publish_clean_leaves_dirty_source_untouched(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)
            _, task_revision = self.create_task_revision(repo, root)

            (repo / "base.txt").write_text("staged source work\n")
            git(repo, "add", "base.txt")
            (repo / "base.txt").write_text("unstaged source work\n")
            (repo / "untracked.txt").write_text("untracked source work\n")
            before = self.source_state(repo)

            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "published")
            self.assertEqual(payload["defaultBranch"], "main")
            self.assertEqual(payload["taskRevisions"][0]["initialEvidence"], "unlanded")
            self.assertEqual(payload["taskRevisions"][0]["evidence"], "patch-equivalent")
            self.assertEqual(before, self.source_state(repo))
            self.assertEqual(
                payload["remoteTip"],
                git(remote, "rev-parse", "refs/heads/main"),
            )
            self.assertEqual("task\n", (root / "task" / "task.txt").read_text())

    def test_publish_clean_retries_one_non_fast_forward(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, remote = self.init_repo(root)
            _, task_revision = self.create_task_revision(repo, root)
            (repo / "untracked.txt").write_text("source dirt\n")

            updater = root / "updater"
            git(root, "clone", str(remote), str(updater))
            git(updater, "config", "user.name", "Done Test")
            git(updater, "config", "user.email", "done@example.invalid")
            (updater / "competitor.txt").write_text("competitor\n")
            git(updater, "add", "competitor.txt")
            git(updater, "commit", "-m", "competitor")

            real_git = shutil.which("git")
            self.assertIsNotNone(real_git)
            wrapper_dir = root / "bin"
            wrapper_dir.mkdir()
            marker = root / "race.marker"
            wrapper = wrapper_dir / "git"
            wrapper.write_text(
                "#!/usr/bin/env python3\n"
                "import os\n"
                "from pathlib import Path\n"
                "import subprocess\n\n"
                "real = os.environ[\"PUBLISH_REAL_GIT\"]\n"
                "marker = Path(os.environ[\"PUBLISH_RACE_MARKER\"])\n"
                "if len(os.sys.argv) > 1 and os.sys.argv[1] == \"push\" and not marker.exists():\n"
                "    subprocess.run([real, \"-C\", os.environ[\"PUBLISH_RACE_UPDATER\"], \"push\", \"origin\", \"main\"], check=True)\n"
                "    marker.write_text(\"raced\\n\")\n"
                "os.execv(real, [real, *os.sys.argv[1:]])\n"
            )
            wrapper.chmod(0o755)
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{wrapper_dir}:{env['PATH']}",
                    "PUBLISH_REAL_GIT": real_git,
                    "PUBLISH_RACE_MARKER": str(marker),
                    "PUBLISH_RACE_UPDATER": str(updater),
                }
            )
            before = self.source_state(repo)

            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "published")
            self.assertEqual(payload["attempts"], 2)
            self.assertEqual(before, self.source_state(repo))
            self.assertEqual(
                {"base.txt", "task.txt", "competitor.txt"},
                set(git(remote, "ls-tree", "-r", "--name-only", "main").splitlines()),
            )

    def test_publish_clean_redacts_remote_credentials_on_failure(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, _ = self.init_repo(root)
            _, task_revision = self.create_task_revision(repo, root)
            git(
                repo,
                "remote",
                "set-url",
                "origin",
                "https://user:secret-token@127.0.0.1:1/repo.git",
            )

            result = self.run_publish_clean(
                "--source-repo",
                str(repo),
                "--task-revision",
                task_revision,
                cwd=repo,
            )

            self.assertEqual(result.returncode, 1)
            self.assertNotIn("secret-token", result.stdout + result.stderr)
            self.assertEqual("blocked", json.loads(result.stdout)["status"])

    @unittest.skipUnless(shutil.which("jj"), "jj is not installed")
    def test_jj_snapshot_and_verify_classification_are_structured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, remote = self.init_repo(root)
            repo = root / "jjrepo"
            subprocess.run(
                ["jj", "git", "clone", str(remote), str(repo)],
                check=True,
                capture_output=True,
                text=True,
            )
            snapshot = self.run_closeout("snapshot", "--repo", str(repo), cwd=repo)
            self.assertEqual(snapshot.returncode, 0, snapshot.stderr)
            snapshot_path = root / "snapshot.json"
            snapshot_path.write_text(snapshot.stdout)
            payload = json.loads(snapshot.stdout)
            self.assertEqual(payload["backend"], "jj")
            self.assertEqual(payload["destination"]["remote"], "origin")
            self.assertTrue(payload["workingCopy"]["clean"])

            result = self.run_closeout(
                "classify",
                "--snapshot",
                str(snapshot_path),
                "--task-revision",
                "@",
                "--authority",
                "verify",
                cwd=repo,
            )
            self.assertEqual(result.returncode, 1)
            classified = json.loads(result.stdout)
            self.assertEqual(classified["status"], "blocked")
            self.assertEqual(classified["taskRevisions"][0]["evidence"], "unlanded")
