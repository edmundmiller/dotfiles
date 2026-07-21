import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "skills" / "catalog" / "skill-quality" / "scripts" / "validate.py"


class SkillQualityValidatorTests(unittest.TestCase):
    def run_validator(self, *paths: Path, json_output: bool = False) -> subprocess.CompletedProcess[str]:
        command = [sys.executable, str(VALIDATOR)]
        if json_output:
            command.append("--json")
        command.extend(str(path) for path in paths)
        return subprocess.run(command, text=True, capture_output=True, check=False)

    def write_skill(self, root: Path, name: str, body: str = "Use this workflow.\n") -> Path:
        skill = root / name
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            "---\n"
            f"name: {name}\n"
            f"description: Validate {name} workflows when reviewing a skill.\n"
            "---\n\n"
            f"# {name}\n\n"
            f"{body}"
        )
        return skill

    def mark_portable(self, skill: Path) -> None:
        path = skill / "SKILL.md"
        path.write_text(path.read_text().replace("description:", "compatibility: portable\ndescription:"))

    def test_accepts_valid_skill_and_emits_structured_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = self.write_skill(Path(tmp), "valid-skill")
            result = self.run_validator(skill, json_output=True)

        self.assertEqual(result.returncode, 0, result.stderr)
        summary = json.loads(result.stdout)
        self.assertEqual(summary["checked"], 1)
        self.assertEqual(summary["findings"], [])

    def test_rejects_missing_frontmatter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = Path(tmp) / "broken-skill"
            skill.mkdir()
            (skill / "SKILL.md").write_text("# Broken\n")
            result = self.run_validator(skill)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("frontmatter", result.stdout)

    def test_rejects_name_that_does_not_match_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = self.write_skill(Path(tmp), "directory-name")
            path = skill / "SKILL.md"
            path.write_text(path.read_text().replace("name: directory-name", "name: other-name"))
            result = self.run_validator(skill)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must match directory", result.stdout)

    def test_rejects_skill_over_500_lines(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            body = "\n".join(f"line {number}" for number in range(501)) + "\n"
            skill = self.write_skill(Path(tmp), "long-skill", body)
            result = self.run_validator(skill)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("500-line limit", result.stdout)

    def test_rejects_broken_relative_link(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = self.write_skill(
                Path(tmp), "linked-skill", "Read [missing guidance](references/missing.md).\n"
            )
            result = self.run_validator(skill)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing local reference", result.stdout)

    def test_portable_skill_rejects_runtime_specific_tool_names(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skill = self.write_skill(
                Path(tmp), "portable-skill", "Call the AskUserQuestion tool before continuing.\n"
            )
            self.mark_portable(skill)
            result = self.run_validator(skill)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("runtime-specific tool name", result.stdout)

    def test_all_owned_skills_pass(self) -> None:
        result = self.run_validator(
            ROOT / "skills" / "catalog",
            ROOT / ".agents" / "skills",
            ROOT / "skills" / "conditional",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
