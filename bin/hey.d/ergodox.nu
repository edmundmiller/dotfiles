use ./common.nu *

def "main ergodox-build" [] {
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

def "main ergodox-flash" [hex: string = ""] {
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

def "main ergodox-build-flash" [] {
  main ergodox-build
  main ergodox-flash
}

def "main ergodox-edit" [] {
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

def "main ergodox-draw" [] {
  let ctx = (context)
  let yaml = ($ctx.flake_dir | path join "config" "ergodox" "keymap.yaml")
  let svg = ($ctx.flake_dir | path join "config" "ergodox" "layout.svg")

  print "Generating keymap visualization..."
  ^uvx --from keymap-drawer keymap draw $yaml -o $svg
  print $"Generated: ($svg)"
}

def "main ergodox-info" [] {
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
