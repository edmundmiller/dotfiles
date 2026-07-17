import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class NodeConfigTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_darwin_node_config_is_nvm_compatible(self) -> None:
        result = subprocess.run(
            [
                "nix",
                "eval",
                "--json",
                f"{ROOT}#darwinConfigurations",
                "--apply",
                """
                configs: builtins.mapAttrs (_: cfg: {
                  hasPrefixEnv = cfg.config.env ? NPM_CONFIG_PREFIX;
                  npmConfig = cfg.config.home.configFile."npm/config".text or "";
                  zshEnvInit = cfg.config.modules.shell.zsh.envInit or "";
                }) configs
                """,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

        for host, config in json.loads(result.stdout).items():
            with self.subTest(host=host):
                self.assertFalse(config["hasPrefixEnv"])
                self.assertNotRegex(config["npmConfig"], r"(?m)^\s*(prefix|globalconfig)\s*=")
                self.assertIn("unset NPM_CONFIG_PREFIX npm_config_prefix", config["zshEnvInit"])


if __name__ == "__main__":
    unittest.main()
