#!/usr/bin/env -S nu --no-config-file
#MISE description="Dry-run a deployment"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [host: string] {
  if $host == $NUC_HOST {
    ^mise run nuc -- dry-activate
    return
  }

  let ctx = (context)
  print $"=== Dry-run deploy to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)" --dry-activate
}
