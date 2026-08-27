import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NUC_CONFIG = ROOT / "hosts" / "nuc" / "default.nix"


class HermesCronExecutorTests(unittest.TestCase):
    def test_darwin_common_checks_do_not_evaluate_nuc_or_deploy(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        checks_start = flake.index("          checks =")
        common_start = flake.index("            // {", checks_start)
        linux_guard = flake.index(
            '            // lib.optionalAttrs (system == "x86_64-linux") {',
            common_start,
        )
        deploy_checks = flake[checks_start:common_start]
        common_checks = flake[common_start:linux_guard]
        linux_checks = flake[linux_guard:]

        self.assertNotIn("self.deploy", common_checks)
        self.assertNotIn("self.nixosConfigurations.nuc", common_checks)
        self.assertIn('lib.optionalAttrs (system == "x86_64-linux")', deploy_checks)
        self.assertIn("deployChecks self.deploy", deploy_checks)
        self.assertIn("ha-automation-assertions", linux_checks)

    def test_cron_executor_source_contract_is_wired_as_a_common_check(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")
        checks_start = flake.index("          checks =")
        common_start = flake.index("            // {", checks_start)
        linux_guard = flake.index(
            '            // lib.optionalAttrs (system == "x86_64-linux") {',
            common_start,
        )
        common_checks = flake[common_start:linux_guard]

        self.assertIn("hermes-cron-executor-source-tests", common_checks)
        self.assertIn("python3 tests/test_hermes_cron_executors.py", common_checks)

    def test_nuc_cron_executor_check_is_linux_only(self):
        flake = (ROOT / "flake.nix").read_text(encoding="utf-8")

        check_position = flake.index("nuc-hermes-cron-executors = import")
        linux_checks_position = flake.index(
            'lib.optionalAttrs (system == "x86_64-linux") ('
        )
        self.assertGreater(
            check_position,
            linux_checks_position,
            "NUC config checks must be defined only in the Linux checks set",
        )

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

    def test_amos_uses_the_patched_canonical_cron_executor(self) -> None:
        config = NUC_CONFIG.read_text(encoding="utf-8")

        self.assertIn(
            'hermesAgentBase = pkgs.llm-agents."hermes-agent";',
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
            'ExecStart = "${hermesAgentBase}/bin/hermes cron tick";',
            config,
        )
        self.assertNotIn("amosburtonHermesLauncher =", config)
        self.assertIn("systemd.timers.hermes-amosburton-cron-tick", config)


if __name__ == "__main__":
    unittest.main()
