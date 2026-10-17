#!/usr/bin/env -S nu --no-config-file
#MISE description="Flash Ergodox firmware"
#MISE raw=true
#MISE raw_args=true
use ../scripts/nu/common.nu *

def main [hex: string = ""] {
  let ctx = (context)
  let ergodox_output = ($ctx.flake_dir | path join "config" "ergodox")

  let hex_file = if ($hex | is-not-empty) {
    $hex
  } else {
    ($ergodox_output | path join "zsa_ergodox_ez_m32u4_base_ergo-drifter.hex")
  }

  if not ($hex_file | path exists) {
    print -e $"Error: Firmware not found: ($hex_file)"
    print -e "Run 'hey ergodox-build' first."
    error make {msg: "firmware hex file not found"}
  }

  print $"Flashing ErgoDox firmware: ($hex_file)"
  print ""

  if ("/Applications/Keymapp.app" | path exists) {
    print "Opening Keymapp..."
    print ""
    print "To flash:"
    print "  1. Click 'Flash from file' in Keymapp"
    print $"  2. Select: ($hex_file)"
    print "  3. Press reset button on keyboard when prompted"
    print ""
    ^open -a Keymapp
  } else if ((^bash -lc "command -v teensy_loader_cli >/dev/null 2>&1" | complete).exit_code == 0) {
    print "WARNING: teensy-loader-cli may fail on macOS (USB driver conflict)"
    print "Consider installing Keymapp: brew install --cask keymapp"
    print ""
    print "Press reset button on keyboard, then press Enter..."
    input
    ^teensy_loader_cli -mmcu=atmega32u4 -w $hex_file
  } else {
    print -e "Error: No flashing tool found."
    print -e "Install Keymapp: brew install --cask keymapp"
    error make {msg: "no flashing tool found"}
  }
}
