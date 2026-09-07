import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def nix_path() -> str:
    # Prefer the system-managed nix: older profile/PATH versions ignore the
    # flake's nixConfig as untrusted and fail on dynamic-derivations.
    system_nix = Path("/run/current-system/sw/bin/nix")
    if system_nix.is_file():
        return str(system_nix)
    profile_nix = Path("/nix/var/nix/profiles/default/bin/nix")
    if profile_nix.is_file():
        return str(profile_nix)
    return shutil.which("nix") or "nix"


class NodeConfigTests(unittest.TestCase):
    def test_bun_global_install_is_idempotent_and_failure_is_fatal(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--json",
                f"{ROOT}#darwinConfigurations",
                "--no-write-lock-file",
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
                self.assertIn("bun install -g --force", activation)
                self.assertNotIn("bun global install failed", activation)
                self.assertNotIn("||", activation)

    def test_bun_force_global_install_succeeds_when_repeated(self) -> None:
        bun = shutil.which("bun")
        if bun is None:
            self.skipTest("bun is not available")

        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            package = temp / "package"
            package.mkdir()
            (package / "package.json").write_text(
                json.dumps(
                    {
                        "name": "activation-idempotency-test",
                        "version": "1.0.0",
                        "bin": {"activation-idempotency-test": "cli.js"},
                    }
                )
            )
            (package / "cli.js").write_text("#!/usr/bin/env bun\n")

            env = {
                "HOME": str(temp / "home"),
                "BUN_INSTALL": str(temp / "bun"),
                "PATH": str(temp / "bun" / "bin"),
            }
            (temp / "home").mkdir()
            command = [bun, "install", "-g", "--force", str(package)]

            first = subprocess.run(command, capture_output=True, text=True, env=env, check=False)
            repeated = subprocess.run(command, capture_output=True, text=True, env=env, check=False)

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(repeated.returncode, 0, repeated.stderr)
            self.assertTrue((temp / "bun" / "bin" / "activation-idempotency-test").exists())

    def test_bun_force_global_install_reports_real_failure(self) -> None:
        bun = shutil.which("bun")
        if bun is None:
            self.skipTest("bun is not available")

        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            env = {
                "HOME": str(temp / "home"),
                "BUN_INSTALL": str(temp / "bun"),
                "PATH": str(temp / "bun" / "bin"),
            }
            (temp / "home").mkdir()
            result = subprocess.run(
                [bun, "install", "-g", "--force", str(temp / "missing-package")],
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)

    def test_darwin_node_config_is_nvm_compatible(self) -> None:
        result = subprocess.run(
            [
                nix_path(),
                "eval",
                "--json",
                f"{ROOT}#darwinConfigurations",
                "--no-write-lock-file",
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
