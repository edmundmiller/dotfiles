#!/usr/bin/env -S nu --no-config-file
#MISE description="Pin an exact Pi release and rebuild the current host"
#MISE alias='pi-update'
#MISE raw=true
#MISE raw_args=true
use ../.lib/common.nu *

def main [version: string] {
  let flake_dir = (context).flake_dir
  ^nix run $"($flake_dir)#pi.updater" -- ($flake_dir | path join "overlays" "pi") $version
  ^mise --cd $flake_dir run rebuild
}
