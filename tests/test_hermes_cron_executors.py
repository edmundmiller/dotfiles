import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NUC_CONFIG = ROOT / "hosts" / "nuc" / "default.nix"


class HermesCronExecutorTests(unittest.TestCase):
    def test_amos_materializes_its_linear_credential_from_1password(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")
        amos_secrets = config.split("  hermesAmosburtonSecrets =", 1)[1].split(
            "  hermesScintillateSecrets =", 1
        )[0]
        materializer = config.split(
            "    hermesAmosburtonSecretsMaterialize =", 1
        )[1].split("    hermesScintillateSecretsMaterialize =", 1)[0]

        self.assertIn(
            'amosLinearCredentialRef = "op://Agents/Amos Linear Bot Team/credential";',
            config,
        )
        self.assertEqual(" hermesProviderSecrets;\n", amos_secrets)
        self.assertIn(
            '${pkgs._1password-cli}/bin/op read ${lib.escapeShellArg amosLinearCredentialRef}',
            materializer,
        )
        self.assertIn(
            "printf 'HERMES_MCP_BEARER_TOKEN_LINEAR=%s\\n'", materializer
        )
        self.assertIn("printf 'LINEAR_API_KEY=%s\\n'", materializer)

    def test_amos_has_one_isolated_canonical_cron_executor(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")

        self.assertIn(
            "amosburtonHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.amosburton-hermes;",
            config,
        )
        self.assertIn("hermesAmosburtonSecretsMaterialize", config)
        self.assertIn("systemd.services.hermes-amosburton-cron-tick", config)
        self.assertIn(
            'ExecStart = "${amosburtonHermesLauncher}/bin/amosburton-hermes cron tick";',
            config,
        )
        self.assertIn("systemd.timers.hermes-amosburton-cron-tick", config)
        self.assertIn("systemd.services.hermes-gateway-amosburton.enable = false;", config)


if __name__ == "__main__":
    unittest.main()
