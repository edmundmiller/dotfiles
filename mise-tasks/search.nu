#!/usr/bin/env -S nu --no-config-file
#MISE description="Search nixpkgs"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [query: string] {
  ^nix search nixpkgs $query
}
