# OpenCode Module - Agent Guide

## Purpose

Nix module for OpenCode CLI. Manages config, rules, agents, skills, commands, and tools.

## Module Structure

```
modules/shell/opencode/
├── default.nix   # Module definition
└── AGENTS.md     # This file

config/opencode/
├── opencode.jsonc    # Main config (symlinked to ~/.config/opencode/)
├── smart-title.jsonc # Smart title config
├── dcp.jsonc         # DCP plugin config
├── rules/            # Global rules (symlinked)
├── agent/            # Custom agents (symlinked)
├── skill/            # Skills (symlinked)
├── command/          # Slash commands (symlinked)
├── tool/             # TypeScript tools (copied, not symlinked)
├── plugin/           # Local plugin development (NOT deployed)
└── package.json      # Dependencies for tools
```

## Key Facts

- **Config/rules/agents/skills/commands:** Nix-managed (symlinked from store, read-only)
- **Tools:** Copied (not symlinked) - TypeScript needs to resolve node_modules
- **Plugins:** User-managed at `~/.config/opencode/plugin/` (except nix-built ones)
- **Plugin cache:** Lives at `~/.cache/opencode/` (NOT nix-managed)

## Troubleshooting

### BunInstallFailedError / Plugin Loading Hangs

**Symptoms:**

- `BunInstallFailedError` with plugin name on startup
- OpenCode hangs indefinitely during plugin loading
- Errors like `Cannot find module '@opencode-ai/plugin'`

**Cause:** Corrupted plugin cache where peer dependencies aren't resolving correctly. Often happens after npm registry issues or interrupted installs.

**Fix:** Clear the opencode plugin cache:

```bash
rm -rf ~/.cache/opencode/node_modules ~/.cache/opencode/bun.lock ~/.cache/opencode/package.json
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

- `modules/shell/claude/` - Sibling module (similar pattern)
- `config/opencode/plugin/*/` - Local plugin development directories
- `hosts/*/default.nix` - Enable with `modules.shell.opencode.enable = true`
