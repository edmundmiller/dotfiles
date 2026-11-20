import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "bin/check-agent-context-layout"


class AgentContextLayoutTests(unittest.TestCase):
    def test_rejects_legacy_instruction_and_skill_paths(self):
        for path in (
            "CLAUDE.md",
            "modules/desktop/term/CLAUDE.md",
            ".pi/skills/example/SKILL.md",
            ".claude/skills/example/SKILL.md",
            "nested/.pi/skills/example/scripts/run.sh",
            "nested/.claude/skills/example",
        ):
            with self.subTest(path=path):
                result = subprocess.run(
                    ["bash", str(CHECK), path], capture_output=True, text=True
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn(path, result.stderr)

    def test_accepts_canonical_paths_and_unrelated_runtime_config(self):
        result = subprocess.run(
            [
                "bash", str(CHECK), "AGENTS.md", "modules/desktop/term/AGENTS.md",
                ".agents/skills/example/SKILL.md",
                "nested/.agents/skills/example/scripts/run.sh",
                ".pi/prompts/example.md", ".claude/settings.json",
                "docs/CLAUDE.md.example", "config/agents/core.md",
            ],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
