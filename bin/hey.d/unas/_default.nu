#!/usr/bin/env -S nu --no-config-file
#MISE description="Deploy the UNAS"
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *
use ../.lib/remote.nu *

def main [mode: string = "remote"] {
  let ctx = (context)
  print "=== Deploying to UNAS ==="
  cd $ctx.flake_dir
  if $mode == "local" {
    if (^hostname -s | str trim) != "unas" {
      error make {msg: "hey unas local must run on the installed UNAS host"}
    }
    with-sudo-path {
      ^sudo -n nixos-rebuild switch --flake .#unas --show-trace --accept-flake-config --max-jobs 2
      if $env.LAST_EXIT_CODE != 0 {
        error make {msg: "UNAS local deployment failed"}
      }
    }
    return
  }
  if $mode != "remote" {
    error make {msg: "hey unas mode must be remote or local"}
  }
  ^nix run .#deploy-rs -- .#unas --skip-checks
}
