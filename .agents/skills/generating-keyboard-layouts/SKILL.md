---
name: generating-keyboard-layouts
description: Generates ErgoDox keyboard layout diagrams as SVG and PNG. Use when asked to visualize a keymap, show keyboard layers, or regenerate this repository's layout illustrations. Not for firmware flashing.
---

# Generating keyboard layouts

Use the existing keymap-drawer workflow, which combines readable key legends with geometry from the firmware's pinned QMK source. This workflow generates illustrations, not changes to keyboard behavior.

## Inputs and ordering

Read `config/ergodox/AGENTS.md` from the repository root before changing illustration sources. `config/ergodox/keymap.yaml` owns the legends, and `packages/ergodox-firmware/src/keymap.c` owns actual key behavior. Keep the illustration consistent with the firmware rather than changing firmware to match the picture.

- Follow the argument order of the QMK layout named in the YAML, including thumb keys. Each layer needs one entry per physical key.
- Physical gaps belong in QMK geometry, not extra YAML entries. An empty string represents a real blank or transparent key, not a spacer.
- Use tap/hold legends such as `{ t: Esc, h: Ctrl }` for dual-role keys. Check both labels against the firmware.

## Generate and inspect

Run from the repository root:

```bash
hey ergodox-draw
```

The command writes `config/ergodox/layout.svg` and supplies the keyboard's `info.json` from `ergodox-firmware.src`. It needs Nix and uvx, but no `qmk setup` or `~/qmk_firmware` checkout. Keep using the pinned source rather than fetching mutable keyboard geometry or copying a Nix store path into YAML. See `packages/ergodox-firmware/default.nix` for the source pin.

For an inline PNG preview, use the installed `rsvg-convert`:

```bash
mkdir -p .amp/in/artifacts
rsvg-convert config/ergodox/layout.svg -o .amp/in/artifacts/ergodox-layout.png
```

Keep `.amp/in/` excluded locally as required by the repository's scratch-file policy. The SVG is the tracked output; the PNG is a review artifact. Regenerate the SVG through `hey ergodox-draw`, not by editing it manually.

Open the PNG with the available image-viewing tool and inspect every generated layer. Check the split geometry, thumb positions, dual-role legends, and clipped or overlapping text against the source. Correct the YAML and regenerate if any position or legend is wrong. A successful renderer exit alone does not establish that the drawing is accurate.

Embed the inspected PNG in the user-facing reply with Markdown image syntax. Use the workspace file URL or the attachment URL returned by the runtime. Show the final capture, not intermediate versions.

## Verification boundary

After changing illustration sources, run `hey check config/ergodox`. Drawing does not verify firmware compilation or keyboard behavior. If the requested task also changes firmware sources, follow the owning guide's `hey ergodox-build` check separately.
