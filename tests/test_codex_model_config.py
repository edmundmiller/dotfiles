import pathlib
import tomllib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "codex" / "config.toml"


class CodexModelConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = tomllib.loads(CONFIG.read_text())

    def test_primary_model_keeps_max_opt_in(self):
        self.assertEqual(self.config["model"], "gpt-5.6-sol")
        self.assertEqual(self.config["model_reasoning_effort"], "high")
        self.assertEqual(
            self.config["enabled-reasoning-efforts"],
            ["medium", "high", "xhigh", "max"],
        )

    def test_native_subagents_use_terra_without_catalog_overrides(self):
        self.assertEqual(
            self.config["agents"],
            {
                "max_concurrent_threads_per_session": 8,
                "default_subagent_model": "gpt-5.6-terra",
                "default_subagent_reasoning_effort": "medium",
            },
        )
        self.assertTrue(self.config["features"]["multi_agent_v2"])
        self.assertNotIn("model_providers", self.config)

    def test_runtime_guidance_and_docs_connector_remain_top_level(self):
        self.assertTrue(self.config["developer_instructions"].startswith("Runtime defaults:"))
        self.assertEqual(
            self.config["mcp_servers"]["openaiDeveloperDocs"]["url"],
            "https://developers.openai.com/mcp",
        )


if __name__ == "__main__":
    unittest.main()
