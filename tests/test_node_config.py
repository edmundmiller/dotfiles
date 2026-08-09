import json
import subprocess
import unittest
from command_paths import nix_path
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NIX = nix_path()


class NodeConfigTests(unittest.TestCase):
    @unittest.skipUnless(NIX, "nix is not installed")
    def test_bun_global_install_has_global_bin_on_path(self) -> None:
        result = subprocess.run(
            [
                NIX,
                "eval",
                "--json",
                f"{ROOT}#darwinConfigurations",
                "--apply",
                """
                configs: builtins.mapAttrs (_: cfg:
                  cfg.config.system.activationScripts.extraActivation.text or ""
                ) configs
                """,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

        activations = json.loads(result.stdout)
        bun_activations = {
            host: text
            for host, text in activations.items()
            if "Ensuring bun global packages:" in text
        }
        self.assertTrue(bun_activations)

        for host, activation in bun_activations.items():
            with self.subTest(host=host):
                self.assertIn("PATH=/Users/emiller/.bun/bin:", activation)

    @unittest.skipUnless(NIX, "nix is not installed")
    def test_darwin_node_config_is_nvm_compatible(self) -> None:
        result = subprocess.run(
            [
                NIX,
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
