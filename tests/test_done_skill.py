from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tests.done_bend import binary

ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills/catalog/done/SKILL.md"
REFERENCES = ROOT / "skills/catalog/done/references"


def git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )


class DoneSkillContractTest(unittest.TestCase):
    def test_bend_laws(self) -> None:
        result = subprocess.run(
            ["bend", "PROOF.bend"], cwd=SKILL.parent, capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("ALL PROOFS CHECK", result.stdout)

    def test_cleanup_guard_resolves_paths_and_preserves_active_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            candidate = root / "task"
            active = candidate / "nested"
            active.mkdir(parents=True)
            sibling = root / "task-other"
            sibling.mkdir()
            alias = root / "alias"
            alias.symlink_to(candidate, target_is_directory=True)
            whitespace_cases = []
            for name in ("task ", "task\n", "task \n\n"):
                target = root / name
                nested = target / "nested"
                nested.mkdir(parents=True)
                whitespace_cases.extend(((nested, target, 1), (nested, candidate, 0)))
            cases = (
                (active, candidate, 1),
                (active, active, 1),
                (active, alias, 1),
                (active, sibling, 0),
                (active, Path("/"), 2),
                (root / "missing", sibling, 2),
                (active, root / "missing", 2),
                *whitespace_cases,
            )
            for current, target, code in cases:
                with self.subTest(current=current, target=target):
                    result = subprocess.run(
                        [binary("verify-workspace-cleanup"), str(current), str(target)],
                        cwd=active,
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(
                        result.returncode, code, result.stdout + result.stderr
                    )
                    self.assertTrue(active.is_dir())
                    self.assertTrue(sibling.is_dir())

    def test_entrypoint_is_a_thin_dispatcher_with_direct_references(self) -> None:
        skill = SKILL.read_text()
        self.assertLessEqual(len(skill.splitlines()), 140)
        for name in ("git.md", "jj.md", "github-pr.md", "cleanup.md"):
            with self.subTest(name=name):
                self.assertIn(f"./references/{name}", skill)
                self.assertTrue((REFERENCES / name).is_file())

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
                [binary("verify-landing"), feature_tip, "main", "origin"],
                cwd=feature,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(0, before.returncode)

            git(repo, "merge", "--ff-only", "feature")
            git(repo, "push", "origin", "main")
            after = subprocess.run(
                [binary("verify-landing"), feature_tip, "main", "origin"],
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
            for key, value in (
                ("user.name", "Done Skill Test"),
                ("user.email", "done-skill@example.invalid"),
            ):
                subprocess.run(
                    ["jj", "config", "set", "--repo", key, value], cwd=repo, check=True
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
                [binary("verify-jj-landing"), task_tip, "main", "origin"],
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
                [binary("verify-jj-landing"), task_tip, "main", "origin"],
                cwd=workspace,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, after.returncode, after.stderr)


if __name__ == "__main__":
    unittest.main()
