# ErgoDox EZ Configuration

This directory contains firmware and configuration for the ErgoDox EZ keyboard.

## Quick Commands

```bash
hey ergodox-flash         # Flash current firmware
hey ergodox-build         # Build firmware from source (QMK)
hey ergodox-build-flash   # Build and flash
hey ergodox-draw          # Generate keymap visualization
hey ergodox-info          # Show firmware info and paths
```

## Layout Overview

**Oryx configurator**: [wagdn/qmvNyL](https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL)

### Layer 0: Base (QWERTY)

Primary typing layer with home-row modifiers and thumb cluster optimizations.

| Feature | Keys | Notes |
|---------|------|-------|
| **Home-row Ctrl** | Caps Lock position | Escape on tap, Ctrl on hold |
| **Layer access** | Thumb clusters | TT(L2), TT(L3) on left; LT(L1) on both sides |
| **Thumb Space** | Left thumb | Space key for primary typing |
| **Thumb Enter** | Right thumb | Enter key with Backspace on LT(L1) |
| **Mod-tap Gui** | Right thumb | Gui on hold, acts as layer modifier |

### Layer 1: Symbols & Navigation

Activated via thumb cluster hold (LT). Provides symbols, F-keys, and arrow navigation.

| Feature | Location | Notes |
|---------|----------|-------|
| **Arrow keys** | HJKL position | Vim-style navigation |
| **F-keys** | Number row | F1-F10 on top row |
| **Symbols** | Home row | !@#$%^&*() easily accessible |
| **Media** | Thumb area | Play/Pause, Prev, Next |
| **Page nav** | Left side | PgUp, PgDn, Home, End |

### Layer 2: Numpad & F-keys

Activated via TT (tap-toggle) on left thumb. Provides numpad and extended F-keys.

| Feature | Location | Notes |
|---------|----------|-------|
| **Numpad** | Right hand | 7-8-9 / 4-5-6 / 1-2-3 / 0 layout |
| **Math ops** | Right pinky | +, -, *, / |
| **F-keys** | Left hand | F1-F20 |
| **Equals** | Right hand | For calculations |

### Layer 3: Mouse & RGB

Activated via TT (tap-toggle) on left thumb. Mouse control and keyboard settings.

| Feature | Location | Notes |
|---------|----------|-------|
| **Mouse cursor** | WASD/ESDF | Up/Down/Left/Right movement |
| **Mouse buttons** | Thumb cluster | Left/Right/Middle click |
| **Scroll wheel** | Left hand | WhlUp, WhlDn, WhlL, WhlR |
| **RGB controls** | Left edge | LED toggle, brightness, speed |
| **Bootloader** | Top right | Reset to flash mode |

## Key Concepts

### Mod-Tap (MT)

Hold for modifier, tap for key:
- `Esc/Ctrl` - Tap for Escape, hold for Control
- `Tab/Gui` - Tap for Tab, hold for Gui (Cmd)
- `Esc/Alt` - Tap for Escape, hold for Alt

### Layer-Tap (LT)

Hold for layer, tap for key:
- `Space/L1` - Tap for Space, hold for Layer 1
- `Bksp/L1` - Tap for Backspace, hold for Layer 1

### Tap-Toggle (TT)

Tap to momentarily activate, double-tap to toggle:
- `TT(L2)` - Access numpad layer
- `TT(L3)` - Access mouse layer

## Files

```
config/ergodox/
├── README.md              # This file
├── keymap.yaml            # Layer documentation for keymap-drawer
├── layout.svg             # Visual layout (generated)
└── firmware/
    └── ergo-drifter/
        ├── zsa_ergodox_ez_m32u4_base_wagdn.hex  # Compiled firmware
        └── zsa_ergodox_ez_m32u4_base_ergo-drifter-fork-fork_source/
            ├── keymap.c   # QMK source
            ├── keymap.json
            ├── config.h
            └── rules.mk
```

## Flashing Firmware

### Using hey (recommended)

```bash
# Flash current firmware
hey ergodox-flash

# Flash specific hex file
hey ergodox-flash path/to/firmware.hex
```

### Using keymapp (ZSA GUI)

1. Open keymapp application
2. Put keyboard in bootloader mode
3. Select firmware file
4. Flash

### Using teensyload (CLI fallback)

```bash
# Put keyboard in bootloader mode first
teensyload config/ergodox/firmware/ergo-drifter/zsa_ergodox_ez_m32u4_base_wagdn.hex
```

## Building Firmware

### From Oryx (easiest)

1. Edit layout at [configure.zsa.io](https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL)
2. Download source from Oryx
3. Replace files in `firmware/ergo-drifter/`
4. Flash with `hey ergodox-flash`

### From Source (QMK)

```bash
# First time setup
qmk setup

# Build
hey ergodox-build

# Build and flash
hey ergodox-build-flash
```

## Dependencies

Managed by nix-darwin via `modules/hardware/ergodox.nix`:

| Package | Purpose |
|---------|---------|
| `teensy-loader-cli` | CLI firmware flasher |
| `qmk` | Build firmware from source |
| `avrdude` | AVR programmer |
| `dfu-programmer` | DFU flasher |
| `dfu-util` | DFU utilities |

Managed by Homebrew:
| Package | Purpose |
|---------|---------|
| `keymapp` | ZSA's GUI firmware tool |

## Troubleshooting

**Keyboard not detected:**
- Ensure keyboard is in bootloader mode (LED pattern changes)
- Check USB connection
- Try `sudo dmesg | tail` to see device events

**Permission denied:**
- Use `hey ergodox-flash` (handles sudo automatically)
- Or prefix with `sudo`: `sudo teensy-loader-cli ...`

**QMK build fails:**
- Run `qmk setup` first
- Ensure `hey rebuild` was run to install dependencies

**keymapp not found:**
- Run `hey rebuild` to install from Homebrew
