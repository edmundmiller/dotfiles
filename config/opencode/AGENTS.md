# OpenCode Configuration - Agent Reference

## Configuration Structure

This directory contains OpenCode configuration managed via nix-darwin.

### Nix-Managed (Read-Only Symlinks)
- `opencode.jsonc` - Main configuration
- `AGENTS.md` - This file (directory agent instructions)
- `GLOBAL_INSTRUCTIONS.md` - Global agent instructions
- `rules/` - Rule files (shell-strategy, etc.)
- `command/` - Slash commands
- `skills/` - Agent skills
- `agent/` - Custom agent definitions


### Nix-Managed (Copied via Activation Script)
- `tool/` - Custom tools (copied so bun can resolve node_modules)
- `package.json` - Dependencies for tools/plugins
- `node_modules/` - Installed via bun install in activation script

### User-Managed (NOT in Nix)
- `plugin/` - **Manually managed** plugin directory

## Plugin Management

**Why plugins aren't in nix:**
- TypeScript plugins need build steps (`bun run build`)
- Development workflow requires flexibility without `hey rebuild`
- OpenCode expects user-managed plugin directory

**Important:** Local plugins must be explicitly registered in `opencode.jsonc` `plugins` array.
Auto-discovery from `~/.config/opencode/plugin/` does NOT work.

**Working with plugins:**

When user asks about installing/updating plugins:
1. Direct them to clone to `~/.config/opencode/plugin/`
2. For TypeScript plugins: run `bun run build` (do NOT run `bun install` - use global deps)
3. Add plugin to `opencode.jsonc` `plugins` array: `"./plugin/<plugin-name>"`

**Required plugins:**
- `opencode-jj` - https://github.com/edmundmiller/opencode-jj (TypeScript, needs build)
- `boomerang-notify` - https://github.com/edmundmiller/boomerang-notify

## Rebuild Workflow

After `hey rebuild`:
- Symlinked files update automatically
- `tool/` directory re-syncs
- `bun install` runs for dependencies
- `plugin/` is UNTOUCHED (user-managed)

## Modifying Configuration

To modify nix-managed files:
1. Edit in `~/.config/dotfiles/config/opencode/`
2. Run `hey rebuild`
3. Changes take effect immediately
