import ipaddress
import json
import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class HostPermissionsTest(unittest.TestCase):
    def test_nfs_exports_and_firewall_share_narrow_networks(self):
        expression = '''
          import ./hosts/unas/nas.nix {
            config.fileSystems."/data/docs" = {};
            lib = rec {
              concatStringsSep = builtins.concatStringsSep;
              concatMapStringsSep = sep: f: xs: concatStringsSep sep (map f xs);
              hasAttr = builtins.hasAttr;
              filter = builtins.filter;
            };
          }
        '''
        result = subprocess.run(
            ["nix-instantiate", "--eval", "--strict", "--json", "--expr", expression],
            cwd=ROOT, text=True, capture_output=True, check=True,
        )
        config = json.loads(result.stdout)
        exports = config["services"]["nfs"]["server"]["exports"]
        ranges = re.findall(r"([\d.]+/\d+)\(rw,no_subtree_check\)", exports)
        self.assertEqual(ranges, ["100.64.0.0/10", "192.168.1.0/24"])
        networks = [ipaddress.ip_network(value) for value in ranges]
        for address, allowed in [
            ("100.64.0.1", True), ("100.127.255.254", True),
            ("100.63.255.254", False), ("100.128.0.1", False),
            ("192.168.1.222", True), ("192.168.2.1", False),
            ("192.0.2.1", False),
        ]:
            self.assertEqual(any(ipaddress.ip_address(address) in n for n in networks), allowed)
        firewall = config["networking"]["firewall"]
        self.assertNotIn(2049, firewall.get("allowedTCPPorts", []))
        self.assertEqual([line for line in firewall["extraCommands"].splitlines() if line], [
            f"iptables -A nixos-fw -p tcp -s {network} --dport 2049 -j nixos-fw-accept"
            for network in ["100.64.0.0/10", "192.168.1.0/24"]
        ])

if __name__ == "__main__":
    unittest.main()
