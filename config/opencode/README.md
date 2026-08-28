---
purpose: Explain the OpenCode V2 config source and deployed runtime paths.
applies_to: Maintaining config/opencode or diagnosing its managed runtime state.
entrypoint: Edit opencode.jsonc, then use modules/agents/opencode/default.nix.
verification: Rebuild and inspect ~/.config/opencode2/opencode.
update_when: OpenCode config, XDG isolation, or plugin ownership changes.
---

# OpenCode configuration

This directory contains OpenCode configuration for the dotfiles repository.

## Structure

### Managed by Nix (via symlinks)

- `opencode.jsonc` - Main OpenCode V2 configuration
- `config/agents/core.md` - Global instructions deployed as V2 `AGENTS.md`
- `command/` - Slash commands deployed under the isolated V2 root
- `config/agents/modes/` - Custom agents deployed under the isolated V2 root

Shared OpenCode skills are discovered from `~/.agents/skills/`; explicit
OpenCode-only skills use `~/.config/opencode/skills/`, a compatibility alias for
the isolated V2 config root.

## Plugin Management

Plugins are not currently deployed by this module. Add a V2-compatible plugin
only after wiring its source and explicit `opencode.jsonc` registration through
the isolated V2 root.

### Plugin Cache & Updates

OpenCode caches npm plugins in `~/.cache/opencode/node_modules/`. Plugins using `@latest`
don't auto-update; clearing the cache forces fresh installs on next launch.

Clear the cache explicitly when a plugin update requires fresh resolution:

```bash
hey opencode-update   # Clear cache only
# Then restart OpenCode
```

**What gets cleared:**

- `~/.cache/opencode/node_modules/` - Installed plugins
- `~/.cache/opencode/bun.lock` - Lock file (forces fresh resolution)

The command preserves:

- `models.json` - Downloaded model configs
- `package.json` - Plugin list

## After System Rebuild

After `hey re`:

- V2 config, `AGENTS.md`, agents, and commands update through Home Manager.
- The incompatible V1 directory is removed.
- Herdr recreates `~/.config/opencode` as an alias to the V2 root when its
  OpenCode integration is enabled.
- Plugin cache contents remain untouched unless `hey opencode-update` is run.

## Development

### Modifying Configurations

1. Edit files in `~/.config/dotfiles/config/opencode/`
2. Run `hey re`
3. Changes take effect immediately
