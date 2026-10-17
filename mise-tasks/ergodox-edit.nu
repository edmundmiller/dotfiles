#!/usr/bin/env -S nu --no-config-file
#MISE description="Edit the Ergodox keymap"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let ergodox_source = ($ctx.flake_dir | path join "packages" "ergodox-firmware" "src")

  if (($env.EDITOR? | default "") | is-not-empty) {
    ^bash -lc $"$EDITOR '($ergodox_source)'"
  } else {
    print $"Keymap source: ($ergodox_source)"
    print ""
    ^ls -la $ergodox_source
    print ""
    print "Set $EDITOR to open in your preferred editor"
  }
}
