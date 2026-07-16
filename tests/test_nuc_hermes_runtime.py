import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class NucHermesRuntimeTest(unittest.TestCase):
    @unittest.expectedFailure
    def test_radar_cron_tick_path_includes_rtk(self):
        source = (ROOT / "hosts/nuc/default.nix").read_text()
        start = source.index("systemd.services.hermes-radar-cron-tick")
        end = source.index("systemd.timers.hermes-radar-cron-tick", start)
        service = source[start:end]
        self.assertIn("pkgs.rtk", service)


if __name__ == "__main__":
    unittest.main()
