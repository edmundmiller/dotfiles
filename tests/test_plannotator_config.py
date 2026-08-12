import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CLEANUP = ROOT / "modules/agents/plannotator/cleanup_codex.py"


class PlannotatorCodexCleanupTests(unittest.TestCase):
    def test_cleanup_removes_only_plannotator_hooks_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            hooks = pathlib.Path(directory) / "hooks.json"
            hooks.write_text(
                json.dumps(
                    {
                        "hooks": {
                            "Stop": [
                                {
                                    "hooks": [
                                        {
                                            "type": "command",
                                            "command": "notify",
                                        },
                                        {
                                            "type": "command",
                                            "command": "/nix/store/plannotator/bin/plannotator",
                                            "timeout": 345600,
                                        },
                                    ]
                                },
                                {
                                    "hooks": [
                                        {
                                            "type": "command",
                                            "command": "plannotator review",
                                        }
                                    ]
                                },
                            ]
                        }
                    }
                ),
                encoding="utf-8",
            )

            for _ in range(2):
                subprocess.run(
                    ["python3", str(CLEANUP), "--codex-hooks", str(hooks)],
                    check=True,
                )

            self.assertEqual(
                json.loads(hooks.read_text(encoding="utf-8")),
                {
                    "hooks": {
                        "Stop": [
                            {
                                "hooks": [
                                    {
                                        "type": "command",
                                        "command": "notify",
                                    }
                                ]
                            }
                        ]
                    }
                },
            )


class PlannotatorSourceContractTests(unittest.TestCase):
    def test_codex_integration_is_absent(self):
        module = (ROOT / "modules/agents/plannotator/default.nix").read_text(
            encoding="utf-8"
        )
        skills = (ROOT / "skills/flake.nix").read_text(encoding="utf-8")

        self.assertNotIn("${./configure.py}", module)
        self.assertNotIn("--codex-config", module)
        self.assertIn("plannotator-codex-cleanup", module)
        self.assertNotIn("inputs.plannotator", skills)
        self.assertNotIn('from = "plannotator"', skills)

    def test_other_agent_integrations_remain_declared(self):
        module = (ROOT / "modules/agents/plannotator/default.nix").read_text(
            encoding="utf-8"
        )
        claude = json.loads(
            (ROOT / "config/claude/settings.json").read_text(encoding="utf-8")
        )

        self.assertIn('version = "0.27.0"', module)
        self.assertIn('piExtensionVersion = "0.27.0"', module)
        self.assertIn("npm:@plannotator/pi-extension@${piExtensionVersion}", module)
        self.assertIn("omp-plannotator-plugin", module)
        self.assertIn("plannotator-claude-plugin", module)
        self.assertIn("herdrEnabled = config.modules.shell.herdr.enable;", module)
        self.assertTrue(claude["enabledPlugins"]["plannotator@plannotator"])
        self.assertEqual(
            claude["extraKnownMarketplaces"]["plannotator"]["source"]["repo"],
            "backnotprop/plannotator",
        )


if __name__ == "__main__":
    unittest.main()
