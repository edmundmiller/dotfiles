import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NUC_CONFIG = ROOT / "hosts" / "nuc" / "default.nix"


class HermesCronExecutorTests(unittest.TestCase):
    @unittest.expectedFailure
    def test_amos_has_one_isolated_canonical_cron_executor(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")

        self.assertIn(
            "amosburtonHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.amosburton-hermes;",
            config,
        )
        self.assertIn('envVar = "HERMES_MCP_BEARER_TOKEN_LINEAR";', config)
        self.assertIn("hermesAmosburtonSecretsMaterialize", config)
        self.assertIn(
            'chown emiller:users "$HERMES_ENV_HOME/cron/jobs.json"', config
        )
        self.assertIn("systemd.services.hermes-amosburton-cron-tick", config)
        self.assertIn(
            'ExecStart = "${amosburtonHermesLauncher}/bin/amosburton-hermes cron tick";',
            config,
        )
        self.assertIn("systemd.timers.hermes-amosburton-cron-tick", config)
        self.assertIn("systemd.services.hermes-gateway-amosburton.enable = false;", config)


if __name__ == "__main__":
    unittest.main()
