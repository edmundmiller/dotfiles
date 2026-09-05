# Overlays

`pkg-list` discovers harness units; `pkg-check <unit>` validates against fresh
upstream sources. The `nix-package-patching` skill covers pin/hash/patch updates.
Host activation is separate and uses `hey`.

- `mapModules ./overlays import` accepts a file or `<name>/default.nix`.
  Supporting patches/locks belong beside the overlay, not in temporary packages.
- Prefer `overrideAttrs` preserving upstream hooks/wrappers. Preserve sibling
  attributes when overriding nested package sets.
- Customized `llm-agents` packages remain nested and are exposed to modules as
  `pkgs.my.<name>` through flake outputs, not ambiguous top-level aliases.
- A `buildNpmPackage` override changing source/lockfile must update both
  `npmDepsHash` and `npmDeps`; otherwise the upstream fixed-output derivation
  can survive. Remove upstream shrinkwrap when a local package-lock is intended.
