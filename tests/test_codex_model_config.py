import pathlib
import tomllib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "codex" / "config.toml"
AGENTS = ROOT / "config" / "codex" / "agents"
MODULE = ROOT / "modules" / "agents" / "codex" / "default.nix"


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

    def test_custom_agent_lanes_pin_models_and_are_deployed(self):
        expected = {
            "luna_worker.toml": ("luna_worker", "gpt-5.6-luna", "max", None),
            "terra_worker.toml": ("terra_worker", "gpt-5.6-terra", "high", None),
            "sol_reviewer.toml": ("sol_reviewer", "gpt-5.6-sol", "high", "read-only"),
        }
        module = MODULE.read_text(encoding="utf-8")

        for filename, values in expected.items():
            profile = tomllib.loads((AGENTS / filename).read_text(encoding="utf-8"))
            name, model, effort, sandbox = values
            self.assertEqual(profile["name"], name)
            self.assertEqual(profile["model"], model)
            self.assertEqual(profile["model_reasoning_effort"], effort)
            self.assertEqual(profile.get("sandbox_mode"), sandbox)
            self.assertTrue(profile["description"])
            self.assertTrue(profile["developer_instructions"])
            self.assertIn(f'".codex/agents/{filename}"', module)

    def test_primary_routes_fresh_context_to_named_agent_lanes(self):
        guidance = self.config["developer_instructions"]

        for agent_name in ("luna_worker", "terra_worker", "sol_reviewer"):
            self.assertIn(agent_name, guidance)
        self.assertIn("fresh context", guidance)
        self.assertIn("actual diff", guidance)
        self.assertIn("rerun the requested verification", guidance)


if __name__ == "__main__":
    unittest.main()
