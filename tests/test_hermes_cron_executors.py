import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NUC_CONFIG = ROOT / "hosts" / "nuc" / "default.nix"


class HermesCronExecutorTests(unittest.TestCase):
    def test_amos_materializes_its_linear_credential_from_opnix(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")
        amos_secrets = config.split("  hermesAmosburtonSecrets =", 1)[1].split(
            "  hermesScintillateSecrets =", 1
        )[0]

        self.assertIn(
            "reference = amosburtonAgentSpec.hermes.dotenvReferences.LINEAR_API_KEY;",
            config,
        )
        self.assertIn('envVar = "LINEAR_API_KEY";', amos_secrets)
        self.assertIn('envVar = "HERMES_MCP_BEARER_TOKEN_LINEAR";', amos_secrets)
        self.assertEqual(
            2,
            amos_secrets.count(
                'path = "/var/lib/opnix/secrets/amosburtonLinearApiKey";'
            ),
        )

    def test_amos_has_one_isolated_canonical_cron_executor(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")

        self.assertIn(
            "amosburtonHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.amosburton-hermes;",
            config,
        )
        self.assertIn('envVar = "LINEAR_API_KEY";', config)
        self.assertIn('envVar = "HERMES_MCP_BEARER_TOKEN_LINEAR";', config)
        self.assertIn(
            'path = "/var/lib/opnix/secrets/amosburtonLinearApiKey";', config
        )
        self.assertIn("hermesAmosburtonSecretsMaterialize", config)
        self.assertNotIn("unset HERMES_MCP_BEARER_TOKEN_LINEAR", config)
        self.assertIn("systemd.services.hermes-amosburton-cron-tick", config)
        self.assertIn(
            'ExecStart = "${amosburtonHermesLauncher}/bin/amosburton-hermes cron tick";',
            config,
        )
        self.assertIn("systemd.timers.hermes-amosburton-cron-tick", config)
        self.assertIn("systemd.services.hermes-gateway-amosburton.enable = false;", config)


if __name__ == "__main__":
    unittest.main()
