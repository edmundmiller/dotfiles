import unittest
import pathlib
import sys
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import agent_read_command as arc


class AgentReadCommandTest(unittest.TestCase):
    def test_pane_target_prefers_terminal_id(self):
        ctx = {"pane": {"pane_id": "w1:p1", "terminal_id": "term_1"}}
        self.assertEqual(arc.pane_target(ctx), "term_1")

    def test_build_command_uses_recent_unwrapped_text(self):
        self.assertEqual(
            arc.build_command("w1:p1"),
            "herdr agent read w1:p1 --source recent-unwrapped --lines 200 --format text",
        )

    def test_tab_target_uses_agent_context(self):
        ctx = {"agent": {"terminal_id": "term_2"}, "tab": {"tab_id": "w1:t1"}}
        self.assertEqual(arc.tab_target(ctx), "term_2")

    def test_tab_target_falls_back_to_agent_list(self):
        ctx = {"tab": {"tab_id": "w1:t1"}}
        payload = {
            "result": {
                "agents": [
                    {"tab_id": "w1:t1", "terminal_id": "idle", "agent_status": "idle"},
                    {"tab_id": "w1:t1", "terminal_id": "blocked", "agent_status": "blocked"},
                ]
            }
        }
        with mock.patch.object(arc, "run_json", return_value=payload):
            self.assertEqual(arc.tab_target(ctx), "blocked")


if __name__ == "__main__":
    unittest.main()
