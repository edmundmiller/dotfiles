# ErgoDox EZ Configuration

This directory contains firmware and configuration for the ErgoDox EZ keyboard.

## Quick Commands

```bash
hey ergodox-build         # Build firmware with pure nix
hey ergodox-flash         # Flash to keyboard (Keymapp GUI)
hey ergodox-build-flash   # Build and flash
hey ergodox-edit          # Edit keymap source
hey ergodox-draw          # Generate keymap visualization
hey ergodox-info          # Show firmware info and paths
```

## Build System

**Pure nix build** - no `~/qmk_firmware` directory required.

The firmware is built entirely with nix, fetching ZSA's QMK fork and compiling
with the AVR cross-toolchain. Build artifacts are cached by nix for fast rebuilds.
The build-only QMK CLI excludes flashing tools and optional Pillow text shaping.
This avoids unrelated graphics dependencies without disabling dependency tests.

`hey ergodox-draw` uses keyboard geometry from the same pinned ZSA source. It
does not require `qmk setup` or a local QMK checkout. The YAML lists exactly 76
keys per layer in `LAYOUT_ergodox_pretty` order, without spacer entries.

```bash
# Build firmware
hey ergodox-build

# Verify build
ls config/ergodox/*.hex
```

### Updating ZSA QMK Firmware

The QMK firmware version is pinned in `packages/ergodox-firmware/default.nix`.
To update:

1. Get the latest SHA:

   ```bash
   git ls-remote https://github.com/zsa/qmk_firmware.git firmware25
   ```

2. Update `packages/ergodox-firmware/default.nix`:
   - Update `zsaRev` to the new SHA
   - Set `zsaHash` to `lib.fakeHash`

3. Build to get the correct hash:

   ```bash
   nix build .#ergodox-firmware 2>&1 | grep "got:"
   ```

4. Update `zsaHash` with the correct value and rebuild and redraw

## Flashing Firmware

### Using hey (recommended)

```bash
hey ergodox-flash
```

Opens Keymapp GUI which handles macOS USB permissions correctly.

### Using Keymapp directly

1. Open Keymapp: `open -a Keymapp`
2. Click "Flash from file"
3. Select: `config/ergodox/zsa_ergodox_ez_m32u4_base_ergo-drifter.hex`
4. Press reset button on keyboard when prompted

### Why Keymapp?

CLI flashing with `teensy-loader-cli` fails on macOS due to USB driver conflicts.
The kernel's HID driver claims the Teensy bootloader before the CLI can access it.
Keymapp (ZSA's official tool) has proper entitlements to handle this.

## Layout Overview

**Oryx configurator**: [wagdn/qmvNyL](https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL)

### Layer 0: Base (QWERTY)

Primary typing layer with home-row modifiers and thumb cluster optimizations.

| Feature           | Keys                           | Notes                                        |
| ----------------- | ------------------------------ | -------------------------------------------- |
| **Home-row Ctrl** | Caps Lock position             | Escape on tap, Control on hold               |
| **Thumb Hyper**   | Inner bottom key on each thumb | Ctrl+Option+Command while held               |
| **Layer access**  | Thumb clusters                 | TT(L2), TT(L3) on left; LT(L1) on both sides |
| **Thumb Space**   | Left thumb                     | Space key for primary typing                 |
| **Thumb Enter**   | Right thumb                    | Enter key with Backspace on LT(L1)           |

The bottom-left key between Alt and Home holds Spaceman's Hyper preset,
Control+Option+Command. Hold it with `1` through `0` to switch workspaces or
`H/J/K/L` to focus tiles. Add Shift to move a window instead. This deliberately
omits Shift from conventional four-modifier Hyper so both actions remain usable.
The two inner-bottom thumb keys use the same Hyper combination, replacing left
Alt/Escape and right Command. Left-thumb Command and the dedicated Alt and Ctrl
keys remain available. Mouse-layer thumb overrides are unchanged.

The Caps Lock-position key keeps Escape on tap and Control on hold, so ordinary
Control shortcuts remain available. The existing 140 ms tapping term and
hold-on-other-key-press setting still apply.

### Layer 1: Symbols & Navigation

Activated via thumb cluster hold (LT). Provides symbols, F-keys, and arrow navigation.

| Feature        | Location      | Notes                         |
| -------------- | ------------- | ----------------------------- |
| **Arrow keys** | HJKL position | Vim-style navigation          |
| **F-keys**     | Number row    | F1-F10 on top row             |
| **Symbols**    | Home row      | !@#$%^&\*() easily accessible |

### Layer 2: Numpad & F-keys

Activated via TT (tap-toggle) on left thumb.

| Feature      | Location    | Notes                            |
| ------------ | ----------- | -------------------------------- |
| **Numpad**   | Right hand  | 7-8-9 / 4-5-6 / 1-2-3 / 0 layout |
| **Math ops** | Right pinky | +, -, \*, /                      |
| **F-keys**   | Left hand   | F1-F20                           |

### Layer 3: Mouse & RGB

Activated via TT (tap-toggle) on left thumb.

| Feature           | Location      | Notes                   |
| ----------------- | ------------- | ----------------------- |
| **Mouse cursor**  | WASD/ESDF     | Movement                |
| **Mouse buttons** | Thumb cluster | Left/Right/Middle click |
| **RGB controls**  | Left edge     | LED toggle, brightness  |
| **Bootloader**    | Top right     | Reset to flash mode     |

## Key Concepts

### Mod-Tap (MT)

Hold for modifier, tap for key:

- `Esc/Ctrl` - Tap for Escape, hold for Control
- `Tab/Gui` - Tap for Tab, hold for Gui (Cmd)

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
├── zsa_ergodox_ez_m32u4_base_ergo-drifter.hex  # Built firmware (untracked)
└── checksum.md5            # Built firmware checksum (untracked)

packages/ergodox-firmware/
├── default.nix             # Pinned ZSA source and AVR build
└── src/
    ├── keymap.c            # QMK keymap source
    ├── config.h            # DEBOUNCE, TAPPING_TERM settings
    └── rules.mk
```

## Editing Keymap

### Using Oryx (easiest)

1. Edit layout at [configure.zsa.io](https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL)
2. Download source from Oryx
3. Replace source files in `packages/ergodox-firmware/src/`
4. Build and flash: `hey ergodox-build-flash`

### Manually editing config

```bash
# Edit source files
hey ergodox-edit

# Common settings in config.h:
#   DEBOUNCE 30      - Key debounce time (ms)
#   TAPPING_TERM 140 - Mod-tap timing (ms)
# Common setting in rules.mk:
#   DEBOUNCE_TYPE sym_eager_pr - per-row eager debounce, good fit for ErgoDox's rotated matrix

# Rebuild and flash
hey ergodox-build-flash
```

## Troubleshooting

**Dropped keys when typing fast:**

- Confirm `DEBOUNCE_TYPE = sym_eager_pr` in `rules.mk`
- If you still get chatter, bump `DEBOUNCE` upward in small steps (current default here: 30ms)
- Rebuild and flash

**Double/triple characters from single keypress (chattering):**

- Raise `DEBOUNCE` in `config.h` by 5-10ms if needed
- If persistent, switch may need replacing

**Flash fails with USB permissions:**

- Use Keymapp GUI (handles permissions automatically)
- CLI flashing not supported on macOS due to kernel driver conflict

**Build fails:**

- Inspect `nix build .#ergodox-firmware --print-build-logs` for the failing derivation.
- Dependencies are declared by the firmware package. A host rebuild is not needed.

**Keymapp not found:**

- Install: `brew install --cask keymapp`
- Or run `hey rebuild` (installs via nix-darwin)
