# Packages

Auto-discovered with `lib.my.mapModules ./packages`: use either `packages/<name>.nix` or `packages/<name>/default.nix`. Packages are exposed as `pkgs.my.*` via the overlay in `flake.nix` and built per-system (`x86_64-linux` and `aarch64-darwin`).

Prefer the `packages/<name>/default.nix` directory pattern when a package may need supporting files such as patches, fixtures, lockfiles, or package-specific `AGENTS.md` guidance.

## Patch policy

- Prefer patch files in `packages/<name>/patches/*.patch` for upstream source changes.
- Keep patch stacks focused and reviewable (small, single-purpose patches applied in order).
- Avoid large inline `postPatch` source-rewrite scripts when the same change can live as a plain patch file.
- If a patch stack is split/reordered, update the corresponding package `default.nix` `patches = [ ... ]` list to match.
