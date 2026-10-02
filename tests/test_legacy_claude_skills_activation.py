import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FLAKE = ROOT / "skills" / "flake.nix"


def extract_activation_script() -> str:
    source = FLAKE.read_text()
    match = re.search(
        r'home\.activation\.remove-legacy-claude-skills = .*?\'\'\n(.*?)\n\s*\'\';',
        source,
        re.DOTALL,
    )
    if match is None:
        raise AssertionError("remove-legacy-claude-skills activation script not found")
    lines = match.group(1).splitlines()
    indentation = min(len(line) - len(line.lstrip()) for line in lines if line.strip())
    return "\n".join(line[indentation:] for line in lines)


class LegacyClaudeSkillsActivationTest(unittest.TestCase):
    def run_activation(self, home: Path) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["HOME"] = str(home)
        return subprocess.run(
            ["bash", "-eu", "-o", "pipefail", "-c", extract_activation_script()],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_moves_ordinary_skills_to_recoverable_backup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            skill = home / ".claude" / "skills" / "personal" / "SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text("irreplaceable user skill\n")

            result = self.run_activation(home)

            backup = home / ".claude" / "skills.pre-dotfiles-agent-skills" / "skills"
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((home / ".claude" / "skills").exists())
            self.assertEqual(
                (backup / "personal" / "SKILL.md").read_text(),
                "irreplaceable user skill\n",
            )
            self.assertIn(str(backup), result.stdout)

    def test_moves_ordinary_file_to_recoverable_backup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            skills = home / ".claude" / "skills"
            skills.parent.mkdir(parents=True)
            skills.write_text("user data\n")

            result = self.run_activation(home)

            backup = home / ".claude" / "skills.pre-dotfiles-agent-skills" / "skills"
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(backup.read_text(), "user data\n")

    def test_removes_only_managed_store_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            skills = home / ".claude" / "skills"
            skills.parent.mkdir(parents=True)
            skills.symlink_to(
                "/nix/store/00000000000000000000000000000000-dotfiles-agent-skills-claude"
            )

            result = self.run_activation(home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(skills.is_symlink())
            self.assertFalse(
                (home / ".claude" / "skills.pre-dotfiles-agent-skills").exists()
            )

    def test_preserves_unknown_and_dangling_symlinks_in_backup(self) -> None:
        for target in ("../user-skills", "../missing-user-skills"):
            with self.subTest(target=target), tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp)
                claude = home / ".claude"
                claude.mkdir()
                if target == "../user-skills":
                    user_skill = home / "user-skills" / "SKILL.md"
                    user_skill.parent.mkdir()
                    user_skill.write_text("user data\n")
                skills = claude / "skills"
                skills.symlink_to(target)

                result = self.run_activation(home)

                backup = claude / "skills.pre-dotfiles-agent-skills" / "skills"
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(backup.is_symlink())
                self.assertEqual(os.readlink(backup), target)
                if target == "../user-skills":
                    self.assertEqual(user_skill.read_text(), "user data\n")

    def test_existing_backup_fails_without_overwriting_either_copy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            skills = home / ".claude" / "skills"
            skills.mkdir(parents=True)
            (skills / "new.txt").write_text("new\n")
            backup = home / ".claude" / "skills.pre-dotfiles-agent-skills"
            backup.mkdir()
            (backup / "old.txt").write_text("old\n")

            result = self.run_activation(home)

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((skills / "new.txt").read_text(), "new\n")
            self.assertEqual((backup / "old.txt").read_text(), "old\n")
            self.assertIn(str(backup), result.stderr)

    def test_unusual_file_type_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            skills = home / ".claude" / "skills"
            skills.parent.mkdir(parents=True)
            os.mkfifo(skills)

            result = self.run_activation(home)

            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(skills.exists())
            self.assertFalse(
                (home / ".claude" / "skills.pre-dotfiles-agent-skills").exists()
            )
            self.assertIn("unusual file type", result.stderr)

    def test_repeated_activation_keeps_backup_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            skills = home / ".claude" / "skills"
            skills.mkdir(parents=True)
            (skills / "saved.txt").write_text("saved\n")

            first = self.run_activation(home)
            second = self.run_activation(home)

            backup_file = (
                home
                / ".claude"
                / "skills.pre-dotfiles-agent-skills"
                / "skills"
                / "saved.txt"
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(backup_file.read_text(), "saved\n")


if __name__ == "__main__":
    unittest.main()
