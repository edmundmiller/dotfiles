import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLOSEOUT = ROOT / "skills/catalog/done/scripts/closeout.py"


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
