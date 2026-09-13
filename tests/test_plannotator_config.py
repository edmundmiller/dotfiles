import json
import pathlib
import subprocess
import sys
import tempfile
import textwrap
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
    def test_claude_bootstrap_drops_plugins_and_preserves_runtime_hooks(self):
        module = (ROOT / "modules/agents/claude/default.nix").read_text()
        bootstrap = module.split("home.activation.claude-settings-bootstrap", 1)[1]
        script = textwrap.dedent(
            bootstrap.split("<<'PY'\n", 1)[1].split("\n          PY", 1)[0]
        )
        hooks = {
            "SessionStart": [{"hooks": [{"type": "command", "command": "herdr hook"}]}]
        }
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / "settings.json"
            target.write_text(
                json.dumps(
                    {
                        "enabledPlugins": {"plannotator@plannotator": True},
                        "extraKnownMarketplaces": {"plannotator": {}},
                        "hooks": hooks,
                    }
                )
            )
            for _ in range(2):
                subprocess.run(
                    [
                        sys.executable,
                        "-c",
                        script,
                        str(target),
                        str(ROOT / "config/claude/settings.json"),
                    ],
                    check=True,
                )
                settings = json.loads(target.read_text())
                self.assertNotIn("enabledPlugins", settings)
                self.assertNotIn("extraKnownMarketplaces", settings)
                self.assertEqual(settings["hooks"], hooks)

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

    def test_claude_plugins_are_absent_and_other_integrations_remain(self):
        module = (ROOT / "modules/agents/plannotator/default.nix").read_text(
            encoding="utf-8"
        )
        claude = json.loads(
            (ROOT / "config/claude/settings.json").read_text(encoding="utf-8")
        )

        self.assertIn('version = "0.27.0"', module)
        self.assertIn('piExtensionVersion = "0.26.4"', module)
        self.assertIn("npm:@plannotator/pi-extension@${piExtensionVersion}", module)
        self.assertIn("extensions = [ ];", module)
        self.assertIn("omp-plannotator-plugin", module)
        self.assertNotIn("plannotator-claude-plugin", module)
        self.assertNotIn("claudeEnabled", module)
        self.assertIn("herdrEnabled = config.modules.shell.herdr.enable;", module)
        self.assertNotIn("enabledPlugins", claude)
        self.assertNotIn("extraKnownMarketplaces", claude)
        self.assertFalse((ROOT / ".claude-plugin/marketplace.json").exists())
        self.assertFalse((ROOT / ".claudelint.toml").exists())
        self.assertFalse(any((ROOT / "config/claude/plugins").rglob("plugin.json")))


if __name__ == "__main__":
    unittest.main()
