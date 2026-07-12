---
purpose: Define packaging and patch-maintenance conventions for local packages.
applies_to: Changes under packages/.
entrypoint: Use pkg-list, then read the target package definition and metadata.
verification: Run pkg-check for declared units and build the affected package.
update_when: Package discovery, patch policy, or maintainer tooling changes.
---

# Packages

Auto-discovered with `lib.my.mapModules ./packages`: use either `packages/<name>.nix` or `packages/<name>/default.nix`. Packages are exposed as `pkgs.my.*` via the overlay in `flake.nix` and built per-system (`x86_64-linux` and `aarch64-darwin`).

Prefer the `packages/<name>/default.nix` directory pattern when a package may need supporting files such as patches, fixtures, lockfiles, or package-specific `AGENTS.md` guidance.

## Maintainer checks

- Run `pkg-list` to find units with optional adjacent `package-harness.json` metadata.
- Run `pkg-check <unit>` for read-only validation against a fresh upstream checkout.
- Use `hey` for deployment and host lifecycle, not package source validation.

## Patch policy

- Prefer patch files in `packages/<name>/patches/*.patch` for upstream source changes.
- Keep patch stacks focused and reviewable (small, single-purpose patches applied in order).
- Avoid large inline `postPatch` source-rewrite scripts when the same change can live as a plain patch file.
- If a patch stack is split/reordered, update the corresponding package `default.nix` `patches = [ ... ]` list to match.
