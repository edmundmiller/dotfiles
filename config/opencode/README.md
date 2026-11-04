---
purpose: Explain the OpenCode config source and deployed runtime paths.
applies_to: Maintaining config/opencode or diagnosing its managed runtime state.
entrypoint: Edit opencode.jsonc, then use modules/agents/opencode/default.nix.
verification: Rebuild and inspect ~/.config/opencode.
update_when: OpenCode config, XDG paths, or plugin ownership changes.
---

# OpenCode configuration

This directory contains configuration for OpenCode V2, installed as `opencode`.

## Structure

### Managed by Nix (via symlinks)

- `opencode.jsonc` - Main configuration, seeded as a writable bootstrap
- `config/agents/core.md` - Global instructions deployed as `AGENTS.md`
- `command/` - Slash commands
- `config/agents/modes/` - Custom agents

Shared OpenCode skills are discovered from `~/.agents/skills/`; explicit
OpenCode-only skills use `~/.config/opencode/skills/`.

## Plugin Management

Plugins are not currently deployed by this module. Add a plugin only after
wiring its source and explicit `opencode.jsonc` registration.

### Plugin Cache & Updates

OpenCode caches npm plugins in `~/.cache/opencode/node_modules/`. Plugins using
`@latest` don't auto-update; clearing the cache forces fresh installs on next
launch.

Clear the cache explicitly when a plugin update requires fresh resolution:

```bash
hey opencode-update   # Clear cache only
# Then restart OpenCode
```

**What gets cleared:**

- `~/.cache/opencode/node_modules/` - Installed plugins
- `~/.cache/opencode/bun.lock` - Lock file (forces fresh resolution)

The command preserves downloaded model configs and the plugin list.

## After System Rebuild

After `hey re`, managed config, `AGENTS.md`, agents, and commands update through
Home Manager. Plugin cache contents remain untouched unless
`hey opencode-update` is run.

## Development

1. Edit files in `~/.config/dotfiles/config/opencode/`.
2. Run `hey re` when activation is authorized.
3. Changes take effect immediately.
