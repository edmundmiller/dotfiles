---
purpose: Route changes to OpenCode V2 configuration sources.
applies_to: Files under config/opencode.
entrypoint: Edit opencode.jsonc or a matching source, then inspect the V2 module.
verification: Rebuild and inspect ~/.config/opencode2/opencode.
update_when: OpenCode config schema, plugins, or managed paths change.
---

# OpenCode configuration

## Configuration Structure

This directory contains OpenCode configuration managed via nix-darwin.

### Nix-Managed (Read-Only Symlinks)

- `opencode.jsonc` - Main V2 configuration
- `config/agents/core.md` - Global runtime instructions, deployed by the module
- `command/` - Slash commands
- `config/agents/modes/` - Custom agent definitions

Shared skills come from `~/.agents/skills/`. Target-specific OpenCode skills
are deployed by `skills/flake.nix` through `~/.config/opencode/skills/`, the
Herdr compatibility alias for the isolated V2 root.

The current module does not deploy `tool/`, `package.json`, `node_modules/`, or
local plugins.

## Plugin Management

Local plugins require explicit V2-compatible source wiring and registration in
`opencode.jsonc`; do not recreate the incompatible V1 plugin tree.

## Rebuild Workflow

After `hey re`:

- Symlinked files update automatically
- The V1 config directory is removed
- Herdr recreates `~/.config/opencode` as a compatibility alias when enabled
- Plugin cache and user-managed content remain untouched

## Modifying Configuration

To modify nix-managed files:

1. Edit the source in this repository.
2. Run `hey re`.
3. Inspect `~/.config/opencode2/opencode/` and run a fresh OpenCode smoke check.
