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

    def test_amos_cron_uses_automatically_refreshed_linear_oauth(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        service_start = source.index("systemd.services.hermes-amosburton-cron-tick")
        service_end = source.index(
            "systemd.timers.hermes-amosburton-cron-tick", service_start
        )
        service = source[service_start:service_end]

        self.assertIn("systemd.services.linear-token-refresh", source)
        self.assertIn("systemd.timers.linear-token-refresh", source)
        self.assertIn("linear-token-refresh.service", service)
        self.assertIn("amosburtonCronExecutor", service)
        self.assertIn(
            'writeShellScript "hermes-amosburton-cron-executor"', source
        )
        self.assertIn("HERMES_MCP_BEARER_TOKEN_LINEAR", source)


if __name__ == "__main__":
    unittest.main()
