#!/usr/bin/env -S nu --no-config-file
#MISE description="Show NUC system status"
#MISE alias="nuc-status"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [] {
  print "=== NUC System Status ==="
  ^ssh $NUC_HOST '
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime)"
    echo ""
    echo "Current Generation:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1
  '
}
