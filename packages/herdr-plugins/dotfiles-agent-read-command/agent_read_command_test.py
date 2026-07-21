import unittest
import pathlib
import sys
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import agent_read_command as arc


class AgentReadCommandTest(unittest.TestCase):
    def test_pane_target_uses_current_pane_id_not_terminal_id(self):
        ctx = {"pane": {"pane_id": "w1:p1", "terminal_id": "term_1"}}
        self.assertEqual(arc.pane_target(ctx), "w1:p1")

    def test_build_command_uses_recent_unwrapped_text(self):
        self.assertEqual(
            arc.build_command("w1:p1"),
            "herdr agent read w1:p1 --source recent-unwrapped --lines 200 --format text",
        )

    def test_tab_target_uses_agent_context(self):
        ctx = {
            "agent": {"name": "reviewer", "pane_id": "w1:p2", "terminal_id": "term_2"},
            "tab": {"tab_id": "w1:t1"},
        }
        self.assertEqual(arc.tab_target(ctx), "w1:p2")

    def test_tab_target_falls_back_to_agent_list(self):
        ctx = {"tab": {"tab_id": "w1:t1"}}
        payload = {
            "result": {
                "agents": [
                    {
                        "tab_id": "w1:t1",
                        "pane_id": "w1:p1",
                        "terminal_id": "idle",
                        "agent_status": "idle",
                    },
                    {
                        "tab_id": "w1:t1",
                        "pane_id": "w1:p2",
                        "terminal_id": "blocked",
                        "agent_status": "blocked",
                    },
                ]
            }
        }
        with mock.patch.object(arc, "run_json", return_value=payload):
            self.assertEqual(arc.tab_target(ctx), "w1:p2")

    def test_terminal_id_alone_is_not_an_agent_target(self):
        self.assertIsNone(arc.pane_target({"pane": {"terminal_id": "term_1"}}))


if __name__ == "__main__":
    unittest.main()
