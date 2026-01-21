# ErgoDox EZ Configuration

This directory contains firmware and configuration for the ErgoDox EZ keyboard.

## Flashing Firmware

The `teensyload` alias (from `modules/hardware/ergodox.nix`) flashes firmware to the keyboard:

```bash
# Put keyboard in bootloader mode (press reset button or use key combo)
teensyload config/ergodox/firmware/ergo-drifter/zsa_ergodox_ez_m32u4_base_wagdn.hex
```

The alias runs: `sudo teensy-loader-cli -w -v --mcu=atmega32u4`

## Firmware

### ergo-drifter

Current layout based on the "ergo-drifter" keymap.

- **Source**: `firmware/ergo-drifter/`
- **Compiled**: `firmware/ergo-drifter/zsa_ergodox_ez_m32u4_base_wagdn.hex`
- **Configurator**: [ZSA Oryx](https://configure.zsa.io/)

Key files:
- `keymap.c` - QMK keymap source
- `keymap.json` - Oryx-compatible JSON layout
- `config.h` - Keyboard configuration
- `rules.mk` - Build rules

## Updating Firmware

1. Edit layout at [configure.zsa.io](https://configure.zsa.io/)
2. Download source from Oryx
3. Add new firmware to `firmware/` directory
4. Flash with `teensyload <path-to-hex>`

## Dependencies

Managed by nix-darwin via `modules/hardware/ergodox.nix`:
- `teensy-loader-cli` - Firmware flasher
- `keymapp` (cask) - ZSA's GUI firmware tool

## Troubleshooting

**Keyboard not detected:**
- Ensure keyboard is in bootloader mode (LED pattern changes)
- Check USB connection
- Try `sudo dmesg | tail` to see device events

**Permission denied:**
- The `teensyload` alias uses `sudo` automatically
