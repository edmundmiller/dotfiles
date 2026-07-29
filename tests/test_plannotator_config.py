import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIGURE = ROOT / "modules/agents/plannotator/configure.py"


class PlannotatorConfigureTests(unittest.TestCase):
    def run_configure(self, config: pathlib.Path, hooks: pathlib.Path) -> None:
        subprocess.run(
            [
                "python3",
                str(CONFIGURE),
                "--codex-config",
                str(config),
                "--codex-hooks",
                str(hooks),
                "--command",
                "/nix/store/plannotator/bin/plannotator",
            ],
            check=True,
        )

    def test_codex_merge_preserves_hooks_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config = root / "config.toml"
            hooks = root / "hooks.json"
            config.write_text("[features]\nrmcp_client = true\n", encoding="utf-8")
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
                                        }
                                    ]
                                }
                            ]
                        }
                    }
                ),
                encoding="utf-8",
            )

            self.run_configure(config, hooks)
            self.run_configure(config, hooks)

            self.assertIn("rmcp_client = true", config.read_text(encoding="utf-8"))
            self.assertIn("hooks = true", config.read_text(encoding="utf-8"))
            stop_hooks = json.loads(hooks.read_text(encoding="utf-8"))["hooks"]["Stop"]
            self.assertEqual(len(stop_hooks), 2)
            self.assertEqual(stop_hooks[0]["hooks"][0]["command"], "notify")
            self.assertEqual(
                stop_hooks[1]["hooks"][0],
                {
                    "type": "command",
                    "command": "/nix/store/plannotator/bin/plannotator",
                    "timeout": 345600,
                },
            )

    def test_codex_merge_updates_an_existing_plannotator_hook(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config = root / "config.toml"
            hooks = root / "hooks.json"
            config.write_text('model = "test"\n', encoding="utf-8")
            hooks.write_text(
                json.dumps(
                    {
                        "hooks": {
                            "Stop": [
                                {
                                    "hooks": [
                                        {
                                            "type": "command",
                                            "command": "plannotator",
                                            "timeout": 1,
                                        }
                                    ]
                                }
                            ]
                        }
                    }
                ),
                encoding="utf-8",
            )

            self.run_configure(config, hooks)

            self.assertIn(
                "[features]\nhooks = true", config.read_text(encoding="utf-8")
            )
            stop_hooks = json.loads(hooks.read_text(encoding="utf-8"))["hooks"]["Stop"]
            self.assertEqual(len(stop_hooks), 1)
            self.assertEqual(
                stop_hooks[0]["hooks"][0]["command"],
                "/nix/store/plannotator/bin/plannotator",
            )
            self.assertEqual(stop_hooks[0]["hooks"][0]["timeout"], 345600)


class PlannotatorSourceContractTests(unittest.TestCase):
    def test_all_agent_integrations_are_declared(self):
        module = (ROOT / "modules/agents/plannotator/default.nix").read_text(
            encoding="utf-8"
        )
        claude = json.loads(
            (ROOT / "config/claude/settings.json").read_text(encoding="utf-8")
        )
        codex = (ROOT / "config/codex/config.toml").read_text(encoding="utf-8")
        skills = (ROOT / "skills/flake.nix").read_text(encoding="utf-8")

        self.assertIn('version = "0.25.0"', module)
        self.assertIn('piExtensionVersion = "0.24.2"', module)
        self.assertIn("npm:@plannotator/pi-extension@${piExtensionVersion}", module)
        self.assertIn("omp-plannotator-plugin", module)
        self.assertIn("plannotator-codex", module)
        self.assertIn("plannotator-claude-plugin", module)
        self.assertIn("herdrEnabled = config.modules.shell.herdr.enable;", module)
        self.assertTrue(claude["enabledPlugins"]["plannotator@plannotator"])
        self.assertEqual(
            claude["extraKnownMarketplaces"]["plannotator"]["source"]["repo"],
            "backnotprop/plannotator",
        )
        self.assertIn("[features]\nhooks = true", codex)
        self.assertIn('url = "github:backnotprop/plannotator/v0.25.0"', skills)
        for skill in (
            "plannotator-review",
            "plannotator-annotate",
            "plannotator-last",
        ):
            self.assertIn(f'{skill}.from = "plannotator"', skills)


if __name__ == "__main__":
    unittest.main()
