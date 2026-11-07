#!/usr/bin/env -S nu --no-config-file
#MISE description="Open a shell with a nixpkgs package"
#MISE raw=true
#MISE raw_args=true
use .lib/common.nu *

def main [package: string] {
  ^nix shell $"nixpkgs#($package)"
}
