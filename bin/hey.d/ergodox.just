# ErgoDox keyboard firmware commands
#
# Uses pure nix build - no ~/qmk_firmware required.
# Keymap source: packages/ergodox-firmware/src/

import 'common.just'

# Firmware paths
ergodox_package := FLAKE_DIR / "packages/ergodox-firmware"
ergodox_source := ergodox_package / "src"
ergodox_output := FLAKE_DIR / "config/ergodox"

# Build ErgoDox firmware using pure nix (no ~/qmk_firmware needed)
ergodox-build:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Building ErgoDox firmware with nix..."
    echo "Source: {{ergodox_source}}"
    echo ""
    
    cd "{{FLAKE_DIR}}"
    nix build .#ergodox-firmware --print-build-logs
    
    # Copy to output directory for easy access
    cp -f result/*.hex "{{ergodox_output}}/"
    cp -f result/*.md5 "{{ergodox_output}}/"
    
    hex=$(ls result/*.hex | head -1)
    echo ""
    echo "Build complete!"
    echo "Firmware: {{ergodox_output}}/$(basename $hex)"
    echo ""
    echo "Flash with: hey ergodox-flash"

# Flash ErgoDox firmware (prefers Keymapp GUI on macOS)
ergodox-flash hex="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Find hex file
    if [[ -n "{{hex}}" ]]; then
        HEX="{{hex}}"
    else
        # Look for built firmware
        HEX="{{ergodox_output}}/zsa_ergodox_ez_m32u4_base_ergo-drifter.hex"
    fi
    
    if [[ ! -f "$HEX" ]]; then
        echo "Error: Firmware not found: $HEX"
        echo "Run 'hey ergodox-build' first."
        exit 1
    fi
    
    echo "Flashing ErgoDox firmware: $HEX"
    echo ""
    
    # Prefer Keymapp GUI (handles macOS USB permissions correctly)
    if [[ -d "/Applications/Keymapp.app" ]]; then
        echo "Opening Keymapp..."
        echo ""
        echo "To flash:"
        echo "  1. Click 'Flash from file' in Keymapp"
        echo "  2. Select: $HEX"
        echo "  3. Press reset button on keyboard when prompted"
        echo ""
        open -a Keymapp
    # Fallback to teensy-loader-cli (may fail on macOS due to USB driver conflict)
    elif command -v teensy_loader_cli >/dev/null 2>&1; then
        echo "WARNING: teensy-loader-cli may fail on macOS (USB driver conflict)"
        echo "Consider installing Keymapp: brew install --cask keymapp"
        echo ""
        echo "Press reset button on keyboard, then press Enter..."
        read -r
        teensy_loader_cli -mmcu=atmega32u4 -w "$HEX"
    else
        echo "Error: No flashing tool found."
        echo "Install Keymapp: brew install --cask keymapp"
        exit 1
    fi

# Build and flash ErgoDox firmware
ergodox-build-flash: ergodox-build ergodox-flash

# Edit ergodox keymap source files
ergodox-edit:
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ -n "${EDITOR:-}" ]]; then
        $EDITOR "{{ergodox_source}}"
    else
        echo "Keymap source: {{ergodox_source}}"
        echo ""
        ls -la "{{ergodox_source}}"
        echo ""
        echo "Set \$EDITOR to open in your preferred editor"
    fi

# Generate keymap visualization SVG
ergodox-draw:
    #!/usr/bin/env bash
    set -euo pipefail
    
    yaml="{{FLAKE_DIR}}/config/ergodox/keymap.yaml"
    svg="{{FLAKE_DIR}}/config/ergodox/layout.svg"
    
    echo "Generating keymap visualization..."
    uvx --from keymap-drawer keymap draw "$yaml" -o "$svg"
    echo "Generated: $svg"

# Show ErgoDox firmware info and current settings
ergodox-info:
    #!/usr/bin/env bash
    echo "ErgoDox EZ - Ergo Drifter Layout"
    echo "================================"
    echo ""
    echo "Build System: Pure nix (no ~/qmk_firmware required)"
    echo ""
    echo "Keymap source:"
    echo "  {{ergodox_source}}/"
    echo ""
    echo "Built firmware:"
    echo "  {{ergodox_output}}/zsa_ergodox_ez_m32u4_base_ergo-drifter.hex"
    echo ""
    echo "Commands:"
    echo "  hey ergodox-build       Build firmware with nix"
    echo "  hey ergodox-flash       Flash to keyboard (Keymapp GUI)"
    echo "  hey ergodox-build-flash Build and flash"
    echo "  hey ergodox-edit        Edit keymap source"
    echo "  hey ergodox-draw        Generate layout SVG"
    echo ""
    echo "Current config:"
    grep -E "DEBOUNCE|TAPPING_TERM" "{{ergodox_source}}/config.h" 2>/dev/null || true
    echo ""
    echo "Oryx configurator:"
    echo "  https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL"
