# OpenCode Configuration

This directory contains OpenCode configuration for the dotfiles repository.

## Structure

### Managed by Nix (via symlinks)
- `opencode.jsonc` - Main OpenCode configuration
- `AGENTS.md` - Agent instructions for this directory
- `GLOBAL_INSTRUCTIONS.md` - Global agent instructions
- `rules/` - Rule files (shell-strategy, etc.)
- `command/` - Slash commands
- `skills/` - Agent skills
- `agent/` - Custom agent definitions


### Managed by Nix (via activation script)
- `tool/` - Custom tools
- `package.json` - Dependencies

### NOT Managed by Nix
- `plugin/` - User-managed plugin directory

## Plugin Management

Plugins are **NOT** managed by nix. Install manually to `~/.config/opencode/plugin/`.

**Important:** Local plugins must be explicitly registered in `opencode.jsonc` `plugins` array.
Auto-discovery from `~/.config/opencode/plugin/` does not work for local plugins.

### Installing Plugins

```bash
cd ~/.config/opencode/plugin/

# jj integration
git clone https://github.com/edmundmiller/opencode-jj.git
cd opencode-jj && bun run build && cd ..

# boomerang notifications  
git clone https://github.com/edmundmiller/boomerang-notify.git
cd boomerang-notify && cd ..
```

**Note:** Do NOT run `bun install` inside plugin directories. Plugins use the global
`@opencode-ai/plugin` dependency from `~/.config/opencode/node_modules/`.

### Registering Plugins

After cloning, add plugins to `opencode.jsonc`:

```jsonc
"plugins": [
  // ... npm plugins ...
  "./plugin/opencode-jj",
  "./plugin/boomerang-notify"
]
```

### Required Plugins

- `opencode-jj` - Jujutsu version control integration
- `boomerang-notify` - Desktop notifications for session completion

## After System Rebuild

After `hey rebuild`:
- Symlinked files update automatically
- Tools get re-synced
- Dependencies update (`bun install` runs)
- **Plugins are untouched** (manual management)

## Development

### Modifying Configurations

1. Edit files in `~/.config/dotfiles/config/opencode/`
2. Run `hey rebuild`
3. Changes take effect immediately

### Adding New Tools

1. Create tool file in `config/opencode/tool/`
2. Run `hey rebuild`
3. Tool syncs to `~/.config/opencode/tool/`

### Plugin Development

Plugins are independent of the nix build:
1. Make changes in `~/.config/opencode/plugin/<plugin-name>/`
2. For TypeScript: `bun run build`
3. Test immediately (no rebuild needed)
