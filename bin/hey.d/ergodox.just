# ErgoDox keyboard firmware commands

import 'common.just'

# Default firmware path
ergodox_firmware := FLAKE_DIR / "config/ergodox/firmware/ergo-drifter"
ergodox_hex := ergodox_firmware / "zsa_ergodox_ez_m32u4_base_wagdn.hex"

# Flash ErgoDox firmware (put keyboard in bootloader mode first)
ergodox-flash hex=ergodox_hex:
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ ! -f "{{hex}}" ]]; then
        echo "Error: Firmware file not found: {{hex}}"
        exit 1
    fi
    
    echo "Flashing ErgoDox firmware: {{hex}}"
    echo "Put keyboard in bootloader mode (press reset button or key combo)..."
    echo ""
    
    # Use keymapp if available (ZSA recommended), fall back to teensy-loader-cli
    if command -v keymapp >/dev/null 2>&1; then
        echo "Using keymapp (ZSA recommended)..."
        keymapp --load "{{hex}}"
    elif command -v teensy-loader-cli >/dev/null 2>&1; then
        echo "Using teensy-loader-cli..."
        sudo teensy-loader-cli -w -v --mcu=atmega32u4 "{{hex}}"
    else
        echo "Error: Neither keymapp nor teensy-loader-cli found"
        echo "Run 'hey rebuild' to install keyboard tools"
        exit 1
    fi
    
    echo ""
    echo "Firmware flashed successfully!"

# Build ErgoDox firmware from source using QMK
ergodox-build:
    #!/usr/bin/env bash
    set -euo pipefail
    
    source_dir="{{ergodox_firmware}}/zsa_ergodox_ez_m32u4_base_ergo-drifter-fork-fork_source"
    
    if [[ ! -d "$source_dir" ]]; then
        echo "Error: Source directory not found: $source_dir"
        exit 1
    fi
    
    echo "Building ErgoDox firmware..."
    echo "Source: $source_dir"
    echo ""
    
    # Check if qmk is available
    if ! command -v qmk >/dev/null 2>&1; then
        echo "Error: qmk not found. Run 'hey rebuild' to install QMK tools."
        exit 1
    fi
    
    # Setup QMK if not already done
    if [[ ! -d ~/qmk_firmware ]]; then
        echo "Setting up QMK firmware repository..."
        qmk setup -y
    fi
    
    # Copy keymap to QMK firmware
    keymap_dir=~/qmk_firmware/keyboards/zsa/ergodox_ez/m32u4/keymaps/ergo-drifter
    mkdir -p "$keymap_dir"
    cp -r "$source_dir"/* "$keymap_dir/"
    
    # Build firmware
    cd ~/qmk_firmware
    qmk compile -kb zsa/ergodox_ez/m32u4 -km ergo-drifter
    
    echo ""
    echo "Build complete! Firmware at:"
    echo "  ~/qmk_firmware/.build/zsa_ergodox_ez_m32u4_ergo-drifter.hex"

# Build and flash ErgoDox firmware
ergodox-build-flash: ergodox-build
    #!/usr/bin/env bash
    set -euo pipefail
    
    hex=~/qmk_firmware/.build/zsa_ergodox_ez_m32u4_ergo-drifter.hex
    
    if [[ ! -f "$hex" ]]; then
        echo "Error: Built firmware not found at $hex"
        exit 1
    fi
    
    echo "Put keyboard in bootloader mode..."
    
    if command -v keymapp >/dev/null 2>&1; then
        keymapp --load "$hex"
    else
        sudo teensy-loader-cli -w -v --mcu=atmega32u4 "$hex"
    fi

# Generate keymap visualization SVG
ergodox-draw:
    #!/usr/bin/env bash
    set -euo pipefail
    
    yaml="{{FLAKE_DIR}}/config/ergodox/keymap.yaml"
    svg="{{FLAKE_DIR}}/config/ergodox/layout.svg"
    
    if [[ ! -f ~/qmk_firmware/keyboards/zsa/ergodox_ez/info.json ]]; then
        echo "QMK not set up. Run 'qmk setup' first."
        echo ""
        echo "The keymap.yaml file still serves as readable layer documentation:"
        echo "  $yaml"
        exit 1
    fi
    
    echo "Generating keymap visualization..."
    uvx --from keymap-drawer keymap draw "$yaml" -o "$svg"
    echo "Generated: $svg"

# Show ErgoDox firmware info
ergodox-info:
    @echo "ErgoDox EZ Configuration"
    @echo "========================"
    @echo ""
    @echo "Current firmware:"
    @echo "  {{ergodox_hex}}"
    @echo ""
    @echo "Source:"
    @echo "  {{ergodox_firmware}}/zsa_ergodox_ez_m32u4_base_ergo-drifter-fork-fork_source/"
    @echo ""
    @echo "Commands:"
    @echo "  hey ergodox-flash         Flash current firmware"
    @echo "  hey ergodox-flash <hex>   Flash specific firmware file"
    @echo "  hey ergodox-build         Build firmware from source"
    @echo "  hey ergodox-build-flash   Build and flash"
    @echo ""
    @echo "Oryx configurator: https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL"
