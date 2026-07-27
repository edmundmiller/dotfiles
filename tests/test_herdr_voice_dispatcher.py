import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = (
    Path(__file__).parents[1]
    / "skills/catalog/herdr-voice-dispatcher/scripts/list_agents.py"
)
SPEC = importlib.util.spec_from_file_location("herdr_voice_list_agents", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class HerdrVoiceDispatcherTests(unittest.TestCase):
    def test_summary_excludes_native_session_reference(self) -> None:
        summary = MODULE.summarize(
            {
                "pane_id": "w1:p2",
                "agent": "reviewer",
                "agent_status": "working",
                "cwd": "/repo",
                "foreground_cwd": "/repo/worktree",
                "terminal_title": "Review diff",
                "focused": True,
                "agent_session": {"value": "/private/session.jsonl"},
            }
        )

        self.assertEqual(
            summary,
            {
                "pane_id": "w1:p2",
                "agent": "reviewer",
                "status": "working",
                "cwd": "/repo/worktree",
                "title": "Review diff",
                "focused": True,
            },
        )
        self.assertNotIn("agent_session", summary)

    def test_load_agents_reports_herdr_failure(self) -> None:
        completed = subprocess.CompletedProcess(
            ["herdr", "agent", "list"],
            returncode=1,
            stdout="",
            stderr="Operation not permitted",
        )

        with patch.object(MODULE.subprocess, "run", return_value=completed):
            with self.assertRaisesRegex(
                SystemExit,
                "herdr agent list failed: Operation not permitted",
            ):
                MODULE.load_agents()

    def test_query_matches_project_title_or_pane(self) -> None:
        agent = {
            "pane_id": "w17:p1P",
            "agent": "omp",
            "status": "working",
            "cwd": "/Users/example/.config/dotfiles",
            "title": "Review skill",
            "focused": False,
        }

        self.assertTrue(MODULE.matches(agent, "dotfiles"))
        self.assertTrue(MODULE.matches(agent, "REVIEW"))
        self.assertTrue(MODULE.matches(agent, "w17:p1p"))
        self.assertFalse(MODULE.matches(agent, "mill-docs"))


if __name__ == "__main__":
    unittest.main()
