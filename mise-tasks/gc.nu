#!/usr/bin/env -S nu --no-config-file
#MISE description="Collect Nix garbage and optionally keep generations"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [--keep-generations] {
  if $keep_generations {
    ^nix-store --gc
    if $env.LAST_EXIT_CODE != 0 {
      error make {msg: "Nix garbage collection failed"}
    }
    return
  }

  if (is-darwin) {
    ^sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old
    ^sudo nix-collect-garbage -d
  }

  ^nix-collect-garbage -d
}
