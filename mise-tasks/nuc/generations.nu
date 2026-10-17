#!/usr/bin/env -S nu --no-config-file
#MISE description="List NUC generations"
#MISE alias="nuc-generations"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [] {
  print "=== NUC System Generations ==="
  ^ssh $NUC_HOST "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"
}
