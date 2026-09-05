# ErgoDox EZ

Firmware source is `packages/ergodox-firmware/src/`: `keymap.c` owns the layout,
`config.h` timing, and `rules.mk` QMK options. This directory owns visualization
metadata (`keymap.yaml`) and generated `layout.svg`.

Commands are in `bin/hey.d/ergodox.nu`: `hey ergodox-build`, `hey ergodox-draw`,
`hey ergodox-info`, and `hey ergodox-edit`. Flashing uses `hey ergodox-flash`
(Keymapp GUI); the macOS CLI has a USB driver conflict. Build uses Nix's AVR
cross-toolchain, without a `~/qmk_firmware` checkout, tested on aarch64-darwin.

For upstream ZSA QMK updates, use the package header and [README.md](README.md).
Oryx source exports replace firmware sources, not the visualization alone.
