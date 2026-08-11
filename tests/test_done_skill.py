from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills/catalog/done/SKILL.md"
FLAKE = ROOT / "skills/flake.nix"
VERIFIER = ROOT / "skills/catalog/done/scripts/verify-landing.sh"
JJ_VERIFIER = ROOT / "skills/catalog/done/scripts/verify-jj-landing.sh"
HERDR_TEARDOWN = (
    ROOT / "skills/catalog/done/scripts/teardown-herdr-worktree.sh"
)


def git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )


class DoneSkillContractTest(unittest.TestCase):
    def test_done_lands_and_publishes_before_cleanup(self) -> None:
        skill = SKILL.read_text()
        flake = FLAKE.read_text()

        for phrase in (
            "actual default branch",
            "Default to direct landing",
            "merge-base --is-ancestor",
            "ls-remote",
            "Never delete a candidate that contains",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, skill)

        self.assertNotIn('done.from = "bholmesdev";', flake)

    def test_launcher_owned_worktrees_use_launcher_teardown(self) -> None:
        skill = SKILL.read_text()

        for phrase in (
            "HERDR_ENV",
            "HERDR_WORKSPACE_ID",
            "teardown-herdr-worktree.sh",
            "CODEX_THREAD_ID",
            "set_thread_archived",
            "without `--force`",
            "Do not archive a same-directory",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, skill)

    def test_dirty_default_attempts_safe_fast_forward_before_blocking(self) -> None:
        skill = SKILL.read_text()

        for phrase in (
            "temporary integration worktree",
            "merge --ff-only",
            "only when Git refuses",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, skill)

        self.assertIn("preservation branch", skill)
        self.assertIn("stash, reset, commit its unrelated dirt", skill)

    def test_dirty_default_fast_forward_preserves_non_overlapping_work(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            feature = root / "feature"

            git(root, "init", "-b", "main", str(repo))
            git(repo, "config", "user.name", "Done Skill Test")
            git(repo, "config", "user.email", "done-skill@example.invalid")
            (repo / "base.txt").write_text("base\n")
            git(repo, "add", "base.txt")
            git(repo, "commit", "-m", "base")
            git(repo, "worktree", "add", "-b", "feature", str(feature), "main")

            (feature / "task.txt").write_text("task\n")
            git(feature, "add", "task.txt")
            git(feature, "commit", "-m", "task")

            (repo / "base.txt").write_text("unrelated tracked edit\n")
            (repo / "untracked.txt").write_text("unrelated untracked edit\n")
            merged = git(repo, "merge", "--ff-only", "feature")

            self.assertIn("Fast-forward", merged.stdout)
            self.assertEqual("unrelated tracked edit\n", (repo / "base.txt").read_text())
            self.assertEqual("unrelated untracked edit\n", (repo / "untracked.txt").read_text())
            self.assertEqual("task\n", (repo / "task.txt").read_text())

    def test_dirty_default_fast_forward_refuses_overlapping_work(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            feature = root / "feature"

            git(root, "init", "-b", "main", str(repo))
            git(repo, "config", "user.name", "Done Skill Test")
            git(repo, "config", "user.email", "done-skill@example.invalid")
            (repo / "state.txt").write_text("base\n")
            git(repo, "add", "state.txt")
            git(repo, "commit", "-m", "base")
            git(repo, "worktree", "add", "-b", "feature", str(feature), "main")

            (feature / "state.txt").write_text("task\n")
            git(feature, "commit", "-am", "task")
            (repo / "state.txt").write_text("user edit\n")

            refused = subprocess.run(
                ["git", "-C", str(repo), "merge", "--ff-only", "feature"],
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(0, refused.returncode)
            self.assertIn("would be overwritten by merge", refused.stderr)
            self.assertEqual("user edit\n", (repo / "state.txt").read_text())

    def test_herdr_teardown_script_refuses_unsafe_cleanup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "repo"
            worktree = root / "worktree"
            wrong_worktree = root / "wrong-worktree"
            mock_herdr = root / "herdr"
            herdr_log = root / "herdr.log"

            git(root, "init", "-b", "main", str(repo))
            git(repo, "config", "user.name", "Done Skill Test")
            git(repo, "config", "user.email", "done-skill@example.invalid")
            (repo / "state.txt").write_text("base\n")
            git(repo, "add", "state.txt")
            git(repo, "commit", "-m", "base")
            git(repo, "worktree", "add", "-qb", "task", str(worktree))

            mock_herdr.write_text(
                """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
workspace_id = os.environ["HERDR_WORKSPACE_ID"]
if args == ["worktree", "list", "--workspace", workspace_id, "--json"]:
    path = os.environ["MOCK_WORKTREE_PATH"]
    print(json.dumps({
        "id": "test",
        "result": {
            "type": "worktree_list",
            "source": {
                "repo_key": "test",
                "repo_name": "repo",
                "repo_root": os.environ["MOCK_REPO_ROOT"],
                "source_checkout_path": os.environ["MOCK_REPO_ROOT"],
            },
            "worktrees": [{
                "path": path,
                "branch": "task",
                "is_bare": False,
                "is_detached": False,
                "is_prunable": False,
                "is_linked_worktree": True,
                "open_workspace_id": workspace_id,
                "label": "task",
            }],
        },
    }))
elif args == ["worktree", "remove", "--workspace", workspace_id, "--json"]:
    Path(os.environ["MOCK_HERDR_LOG"]).write_text(" ".join(args) + "\\n")
    print(json.dumps({
        "id": "test",
        "result": {
            "type": "worktree_removed",
            "workspace_id": workspace_id,
            "path": os.environ["MOCK_WORKTREE_PATH"],
            "forced": False,
        },
    }))
else:
    print(f"unexpected herdr arguments: {args}", file=sys.stderr)
    raise SystemExit(2)
"""
            )
            mock_herdr.chmod(0o755)

            base_env = {
                key: value
                for key, value in os.environ.items()
                if not key.startswith("HERDR_")
            }
            base_env.update(
                {
                    "HERDR_BIN_PATH": str(mock_herdr),
                    "MOCK_HERDR_LOG": str(herdr_log),
                    "MOCK_REPO_ROOT": str(repo),
                    "MOCK_WORKTREE_PATH": str(worktree),
                }
            )

            outside_herdr = subprocess.run(
                ["bash", str(HERDR_TEARDOWN), str(worktree)],
                cwd=worktree,
                env=base_env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, outside_herdr.returncode)
            self.assertIn("HERDR_ENV=1", outside_herdr.stderr)

            herdr_env = base_env | {
                "HERDR_ENV": "1",
                "HERDR_WORKSPACE_ID": "workspace-test",
                "MOCK_WORKTREE_PATH": str(wrong_worktree),
            }
            wrong_provenance = subprocess.run(
                ["bash", str(HERDR_TEARDOWN), str(worktree)],
                cwd=worktree,
                env=herdr_env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, wrong_provenance.returncode)
            self.assertIn("does not own", wrong_provenance.stderr)
            self.assertFalse(herdr_log.exists())

            herdr_env["MOCK_WORKTREE_PATH"] = str(worktree)
            dirty_file = worktree / "dirty.txt"
            dirty_file.write_text("dirty\n")
            dirty = subprocess.run(
                ["bash", str(HERDR_TEARDOWN), str(worktree)],
                cwd=worktree,
                env=herdr_env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, dirty.returncode)
            self.assertIn("not clean", dirty.stderr)
            self.assertFalse(herdr_log.exists())
            dirty_file.unlink()

            safe = subprocess.run(
                ["bash", str(HERDR_TEARDOWN), str(worktree)],
                cwd=worktree,
                env=herdr_env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, safe.returncode, safe.stderr)
            remove_args = herdr_log.read_text().strip()
            self.assertEqual(
                "worktree remove --workspace workspace-test --json",
                remove_args,
            )
            self.assertNotIn("--force", remove_args)

    def test_verifier_requires_published_default_branch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            remote = root / "remote.git"
            repo = root / "repo"
            feature = root / "feature"

            subprocess.run(
                ["git", "init", "--bare", str(remote)],
                check=True,
                capture_output=True,
            )
            git(root, "init", "-b", "main", str(repo))
            git(repo, "config", "user.name", "Done Skill Test")
            git(repo, "config", "user.email", "done-skill@example.invalid")
            (repo / "state.txt").write_text("base\n")
            git(repo, "add", "state.txt")
            git(repo, "commit", "-m", "base")
            git(repo, "remote", "add", "origin", str(remote))
            git(repo, "push", "-u", "origin", "main")
            git(repo, "worktree", "add", "-b", "feature", str(feature), "main")
            (feature / "state.txt").write_text("feature\n")
            git(feature, "commit", "-am", "feature")
            feature_tip = git(feature, "rev-parse", "HEAD").stdout.strip()

            before = subprocess.run(
                ["bash", str(VERIFIER), feature_tip, "main", "origin"],
                cwd=feature,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, before.returncode)

            git(repo, "merge", "--ff-only", "feature")
            git(repo, "push", "origin", "main")
            after = subprocess.run(
                ["bash", str(VERIFIER), feature_tip, "main", "origin"],
                cwd=feature,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, after.returncode, after.stderr)

    @unittest.skipUnless(shutil.which("jj"), "jj is not installed")
    def test_jj_verifier_requires_local_and_remote_bookmark_alignment(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            remote = root / "remote.git"
            repo = root / "repo"
            workspace = root / "workspace"

            subprocess.run(["git", "init", "--bare", str(remote)], check=True)
            git(root, "init", "-b", "main", str(repo))
            git(repo, "config", "user.name", "Done Skill Test")
            git(repo, "config", "user.email", "done-skill@example.invalid")
            (repo / "state.txt").write_text("base\n")
            git(repo, "add", "state.txt")
            git(repo, "commit", "-m", "base")
            git(repo, "remote", "add", "origin", str(remote))
            git(repo, "push", "-u", "origin", "main")
            subprocess.run(
                ["jj", "git", "init", "--colocate", str(repo)],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                ["jj", "bookmark", "track", "main@origin"],
                cwd=repo,
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                [
                    "jj",
                    "workspace",
                    "add",
                    "-R",
                    str(repo),
                    str(workspace),
                    "-r",
                    "main",
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            (workspace / "state.txt").write_text("feature\n")
            subprocess.run(
                ["jj", "describe", "-m", "feature"], cwd=workspace, check=True
            )
            task_tip = subprocess.run(
                ["jj", "log", "-r", "@", "--no-graph", "-T", 'change_id ++ "\\n"'],
                cwd=workspace,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()

            before = subprocess.run(
                ["bash", str(JJ_VERIFIER), task_tip, "main", "origin"],
                cwd=workspace,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, before.returncode)

            subprocess.run(
                ["jj", "bookmark", "set", "main", "-r", task_tip],
                cwd=workspace,
                check=True,
            )
            subprocess.run(
                ["jj", "git", "push", "--remote", "origin", "--bookmark", "main"],
                cwd=workspace,
                check=True,
            )
            subprocess.run(
                ["jj", "git", "fetch", "--remote", "origin"], cwd=workspace, check=True
            )
            after = subprocess.run(
                ["bash", str(JJ_VERIFIER), task_tip, "main", "origin"],
                cwd=workspace,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, after.returncode, after.stderr)


if __name__ == "__main__":
    unittest.main()
