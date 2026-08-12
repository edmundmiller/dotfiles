import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATOR = ROOT / "skills" / "scripts" / "adopt-legacy-agent-skills.py"


class AgentSkillsMarkerMigrationTests(unittest.TestCase):
    def run_migrator(self, destination: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "python3",
                str(MIGRATOR),
                str(destination),
                "/nix/store/test-bundle",
                "agents",
                "copy-tree",
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    @unittest.expectedFailure
    def test_adopts_legacy_nix_managed_copy_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "skills"
            skill = destination / "example"
            skill.mkdir(parents=True)
            skill_file = skill / "SKILL.md"
            skill_file.write_text("legacy bundle content\n")
            os.utime(skill_file, (1, 1))
            os.utime(skill, (1, 1))

            mutable = destination / ".system"
            mutable.mkdir()
            (mutable / "local-skill").write_text("runtime state\n")

            result = self.run_migrator(destination)

            self.assertEqual(result.returncode, 0, result.stderr)
            marker = json.loads(
                (destination / ".agent-skills-managed.json").read_text()
            )
            self.assertEqual(marker["managedBy"], "agent-skills-nix")
            self.assertEqual(marker["target"], "agents")
            self.assertEqual(marker["structure"], "copy-tree")
            self.assertTrue((mutable / "local-skill").exists())

    @unittest.expectedFailure
    def test_does_not_adopt_locally_modified_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / "skills"
            destination.mkdir()
            (destination / "manual-skill").write_text("keep me\n")

            result = self.run_migrator(destination)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(
                (destination / ".agent-skills-managed.json").exists()
            )


if __name__ == "__main__":
    unittest.main()
