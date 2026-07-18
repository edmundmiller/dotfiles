import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class NucHermesRuntimeTest(unittest.TestCase):
    def test_radar_cron_tick_path_includes_rtk(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        start = source.index("systemd.services.hermes-radar-cron-tick")
        end = source.index("systemd.timers.hermes-radar-cron-tick", start)
        service = source[start:end]
        self.assertIn("pkgs.rtk", service)

    def test_amos_cron_uses_canonical_linear_api_credential(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        service_start = source.index("systemd.services.hermes-amosburton-cron-tick")
        service_end = source.index(
            "systemd.timers.hermes-amosburton-cron-tick", service_start
        )
        service = source[service_start:service_end]

        self.assertIn("amosburtonCronExecutor", service)
        self.assertIn(
            'writeShellScript "hermes-amosburton-cron-executor"', source
        )
        self.assertIn("amosburtonAgentSpec.hermes.dotenvReferences.LINEAR_API_KEY", source)
        self.assertIn("SupplementaryGroups", service)
        self.assertIn('"onepassword-secrets"', service)

    @unittest.expectedFailure
    def test_scintillate_cron_pins_profile_home_for_terminal_tools(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        service_start = source.index("systemd.services.hermes-scintillate-cron-tick")
        service_end = source.index(
            "systemd.timers.hermes-scintillate-cron-tick", service_start
        )
        service = source[service_start:service_end]

        self.assertIn("HOME=/var/lib/hermes-scintillate", service)
        self.assertIn(
            "HERMES_HOME=/var/lib/hermes-scintillate/.hermes", service
        )
        self.assertIn("HERMES_REAL_HOME=/var/lib/hermes-scintillate", service)
        self.assertIn("TERMINAL_HOME_MODE=real", service)


if __name__ == "__main__":
    unittest.main()
