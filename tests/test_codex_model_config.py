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

    def test_runtime_guidance_remains_top_level(self):
        self.assertTrue(self.config["developer_instructions"])

    def test_custom_agent_lanes_are_deployed_with_read_only_reviewer(self):
        expected = {
            "luna_worker.toml": ("luna_worker", None),
            "terra_worker.toml": ("terra_worker", None),
            "sol_reviewer.toml": ("sol_reviewer", "read-only"),
        }
        module = MODULE.read_text(encoding="utf-8")

        for filename, values in expected.items():
            profile = tomllib.loads((AGENTS / filename).read_text(encoding="utf-8"))
            name, sandbox = values
            self.assertEqual(profile["name"], name)
            self.assertEqual(profile.get("sandbox_mode"), sandbox)
            self.assertTrue(profile["description"])
            self.assertTrue(profile["developer_instructions"])
            self.assertIn(f'".codex/agents/{filename}"', module)


if __name__ == "__main__":
    unittest.main()
