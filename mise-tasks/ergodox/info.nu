#!/usr/bin/env -S nu --no-config-file
#MISE description="Show Ergodox firmware information"
#MISE alias="ergodox-info"
#MISE raw=true
#MISE raw_args=true
use ../../scripts/nu/common.nu *

def main [] {
  let ctx = (context)
  let ergodox_source = ($ctx.flake_dir | path join "packages" "ergodox-firmware" "src")
  let ergodox_output = ($ctx.flake_dir | path join "config" "ergodox")

  print "ErgoDox EZ - Ergo Drifter Layout"
  print "================================"
  print ""
  print "Build System: Pure nix (no ~/qmk_firmware required)"
  print ""
  print "Keymap source:"
  print $"  ($ergodox_source)/"
  print ""
  print "Built firmware:"
  print $"  ($ergodox_output)/zsa_ergodox_ez_m32u4_base_ergo-drifter.hex"
  print ""
  print "Commands:"
  print "  hey ergodox-build       Build firmware with nix"
  print "  hey ergodox-flash       Flash to keyboard (Keymapp GUI)"
  print "  hey ergodox-build-flash Build and flash"
  print "  hey ergodox-edit        Edit keymap source"
  print "  hey ergodox-draw        Generate layout SVG"
  print ""
  print "Current config:"
  let config_h = ($ergodox_source | path join "config.h")
  let cfg = (^grep -E "DEBOUNCE|TAPPING_TERM" $config_h | complete)
  if $cfg.exit_code == 0 {
    print $cfg.stdout
  }
  print ""
  print "Oryx configurator:"
  print "  https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL"
}
