#!/usr/bin/env -S nu --no-config-file
#MISE description="Deploy a host with deploy-rs"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *
use ../../scripts/nu/remote.nu *

def main [host: string] {
  let ctx = (context)
  print $"=== Deploying to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)"
}
