#!/usr/bin/env -S nu --no-config-file
#MISE description="Render the Ergodox keymap"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let yaml = ($ctx.flake_dir | path join "config" "ergodox" "keymap.yaml")
  let svg = ($ctx.flake_dir | path join "config" "ergodox" "layout.svg")

  print "Generating keymap visualization..."
  ^uvx --from keymap-drawer keymap draw $yaml -o $svg
  print $"Generated: ($svg)"
}
