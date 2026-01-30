# ErgoDox Configuration

Documentation and visualization for ErgoDox EZ keyboard.

## Directory Structure

```
config/ergodox/
├── AGENTS.md              # This file
├── README.md              # Human documentation (comprehensive guide)
├── keymap.yaml            # Layout metadata for keymap-drawer
├── layout.svg             # Generated visualization
└── *.hex                  # Build artifacts (gitignored)

packages/ergodox-firmware/
├── default.nix            # Build derivation (AVR cross-compile)
├── README.md              # Package documentation
└── src/
    ├── keymap.c           # THE KEYMAP (edit this)
    ├── config.h           # DEBOUNCE, TAPPING_TERM settings
    ├── rules.mk           # QMK build rules
    └── keymap.json        # Oryx export format
```

## Related Files

| File                           | Purpose                          |
| ------------------------------ | -------------------------------- |
| `packages/ergodox-firmware/`   | Keymap source + build derivation |
| `modules/hardware/ergodox.nix` | Nix module (installs QMK tools)  |
| `bin/hey.d/ergodox.just`       | Workflow commands                |

## Key Facts

- **Build system**: Pure nix, no `~/qmk_firmware` required
- **Cross-compilation**: AVR toolchain via `pkgsCross.avr`
- **Darwin-only**: Build tested on aarch64-darwin
- **Flashing**: Use Keymapp GUI (CLI fails on macOS due to USB driver conflict)
- **Oryx**: Layout editable at configure.zsa.io, download source to replace files

## Commands

```bash
hey ergodox-build       # Build firmware
hey ergodox-flash       # Flash via Keymapp
hey ergodox-build-flash # Both
hey ergodox-edit        # Open source in $EDITOR
hey ergodox-draw        # Generate layout.svg
hey ergodox-info        # Show paths and settings
```

## Common Edits

**Keymap changes**: Edit `packages/ergodox-firmware/src/keymap.c`

- Keycodes: `KC_A`, `KC_ENTER`, `KC_LGUI`, etc.
- Mod-tap: `MT(MOD_LCTL, KC_ESC)` = Ctrl on hold, Esc on tap
- Layer-tap: `LT(1, KC_SPACE)` = Layer 1 on hold, Space on tap

**Timing issues**: Edit `packages/ergodox-firmware/src/config.h`

- `DEBOUNCE 5` - Key debounce (ms), raise if chattering
- `TAPPING_TERM 140` - Mod-tap timing (ms)

## Updating ZSA QMK Version

See `packages/ergodox-firmware/default.nix` header for instructions.
