import pathlib
import tomllib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "codex" / "config.toml"


class CodexModelConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = tomllib.loads(CONFIG.read_text())

    def test_primary_model_uses_balanced_default_with_max_opt_in(self):
        self.assertEqual(self.config["model"], "gpt-5.6-sol")
        self.assertEqual(self.config["model_reasoning_effort"], "medium")
        self.assertEqual(
            self.config["enabled-reasoning-efforts"],
            ["medium", "high", "xhigh", "max"],
        )

    def test_sol_uses_bounded_luna_subagents_without_catalog_overrides(self):
        self.assertEqual(
            self.config["agents"],
            {
                "enabled": True,
                "max_concurrent_threads_per_session": 100,
                "default_subagent_model": "gpt-5.6-luna",
                "default_subagent_reasoning_effort": "max",
            },
        )
        self.assertTrue(self.config["features"]["multi_agent_v2"])
        self.assertNotIn("model_providers", self.config)
        guidance = self.config["developer_instructions"]
        self.assertIn("Keep Sol as the primary coordinator", guidance)
        self.assertIn("normally one to three", guidance)
        self.assertIn("never delegate recursively", guidance)

    def test_runtime_guidance_and_docs_connector_remain_top_level(self):
        self.assertTrue(self.config["developer_instructions"].startswith("Runtime defaults:"))
        self.assertEqual(
            self.config["mcp_servers"]["openaiDeveloperDocs"]["url"],
            "https://developers.openai.com/mcp",
        )


if __name__ == "__main__":
    unittest.main()
