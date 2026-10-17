#!/usr/bin/env -S nu --no-config-file
#MISE description="Deploy the UNAS"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *
use ../scripts/nu/remote.nu *

def main [] {
  let ctx = (context)
  print "=== Deploying to UNAS ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- .#unas --skip-checks
}
