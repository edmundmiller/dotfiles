from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills/catalog/done/SKILL.md"
FLAKE = ROOT / "skills/flake.nix"
VERIFIER = ROOT / "skills/catalog/done/scripts/verify-landing.sh"


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
            "Do not remove the worktree",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, skill)

        self.assertNotIn('done.from = "bholmesdev";', flake)

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


if __name__ == "__main__":
    unittest.main()
