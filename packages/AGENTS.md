# Packages

Auto-discovered from `packages/*.nix` and exposed as `pkgs.my.*` via the overlay in `flake.nix`. Built per-system (`x86_64-linux` and `aarch64-darwin`).

## Patch policy

- Prefer patch files in `packages/<name>/patches/*.patch` for upstream source changes.
- Keep patch stacks focused and reviewable (small, single-purpose patches applied in order).
- Avoid large inline `postPatch` source-rewrite scripts when the same change can live as a plain patch file.
- If a patch stack is split/reordered, update the corresponding package `default.nix` `patches = [ ... ]` list to match.
