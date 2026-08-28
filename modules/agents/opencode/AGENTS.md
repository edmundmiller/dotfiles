---
purpose: Route changes to the isolated OpenCode V2 module and managed config.
applies_to: Files under modules/agents/opencode.
entrypoint: Edit default.nix and config/opencode sources.
verification: Rebuild, inspect the V2 XDG root, and run an OpenCode smoke check.
update_when: OpenCode version, XDG root, instruction discovery, or paths change.
---

# OpenCode module

## Purpose

Nix module for OpenCode V2. It isolates V2 from incompatible V1 plugins and
manages config, global instructions, agents, and commands.

## Module Structure

```
modules/agents/opencode/
├── default.nix   # Module definition
└── AGENTS.md     # This file

config/opencode/
├── opencode.jsonc # Main config
├── agent/         # Historical source; shared modes come from config/agents/modes
└── command/       # Slash commands
```

## Key Facts

- **Config/core/agents/commands:** Nix-managed in
  `~/.config/opencode2/opencode/` (symlinked from the store, read-only)
- **Global instructions:** `config/agents/core.md` is installed as
  `~/.config/opencode2/opencode/AGENTS.md`; V2 does not load the old rules glob.
- **Shared skills:** Discovered from `~/.agents/skills/`; explicitly targeted
  OpenCode skills use the compatibility alias `~/.config/opencode/skills/`.
- **V1 cleanup:** Activation removes the incompatible V1 config directory before
  Herdr recreates `~/.config/opencode` as an alias to the isolated V2 directory.
- **Plugin cache:** Lives at `~/.cache/opencode/` (not Nix-managed)

## Troubleshooting

### BunInstallFailedError / Plugin Loading Hangs

**Symptoms:**

- `BunInstallFailedError` with plugin name on startup
- OpenCode hangs indefinitely during plugin loading
- Errors like `Cannot find module '@opencode-ai/plugin'`

**Cause:** Corrupted plugin cache where peer dependencies aren't resolving correctly. Often happens after npm registry issues or interrupted installs.

**Fix:** Clear the OpenCode plugin cache through the guarded command:

```bash
hey opencode-update
```

Then restart opencode - it will reinstall all plugins fresh.

### Plugin 404 Errors

If you see 404 errors for plugin tarballs, the npm registry may be propagating a new publish. Wait a few minutes and retry:

```bash
# Check if tarball is available
curl -sI "https://registry.npmjs.org/@opencode-ai/plugin/-/plugin-VERSION.tgz" | head -3

# Should show HTTP/2 200 when ready
```

## Related Files

- `modules/agents/claude/` - Sibling module (similar pattern)
- `hosts/*/default.nix` - Enable with `modules.agents.opencode.enable = true`
