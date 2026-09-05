# Hermes NixOS wiring

This module owns package/bootstrap/deployment, not reusable runtime/profile
behavior (owned by `agents-workspace`). Mac CLI wiring uses `hermes-local`;
Desktop installation is separate.

Activation resolves/migrates `HERMES_HOME`, writes SOUL/skins, merges declarative
overlays into writable `config.yaml`, and materializes `.env`. These are normal
mutable files, not store symlinks. Durable seed sources live in `config/hermes/`.

MCP servers use environment interpolation. Host `secretReferences` maps names
to 1Password paths; plaintext credentials belong neither in config nor Nix.
`hermes-runtime-drift` only reports drift. `hermes doctor` checks providers and
API connectivity; package/host build checks establish deployment validity.
