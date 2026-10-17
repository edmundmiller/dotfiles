#!/usr/bin/env -S nu --no-config-file
#MISE description="Build Ergodox firmware"
#MISE alias="ergodox-build"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let ergodox_source = ($ctx.flake_dir | path join "packages" "ergodox-firmware" "src")
  let ergodox_output = ($ctx.flake_dir | path join "config" "ergodox")

  print "Building ErgoDox firmware with nix..."
  print $"Source: ($ergodox_source)"
  print ""

  cd $ctx.flake_dir
  ^nix build .#ergodox-firmware --print-build-logs

  ^cp -f result/*.hex $"($ergodox_output)/"
  ^cp -f result/*.md5 $"($ergodox_output)/"

  let hex = (^bash -lc "ls result/*.hex | head -1" | str trim)
  print ""
  print "Build complete!"
  print $"Firmware: ($ergodox_output)/($hex | path basename)"
  print ""
  print "Flash with: hey ergodox-flash"
}
