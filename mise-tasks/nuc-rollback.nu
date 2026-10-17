#!/usr/bin/env -S nu --no-config-file
#MISE description="Roll back the NUC generation"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [] {
  print "Rolling back NUC to previous generation..."
  ^ssh -t $NUC_HOST "sudo nix-private-github nixos-rebuild --rollback switch"
}
