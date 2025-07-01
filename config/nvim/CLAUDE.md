# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a LazyVim configuration repository based on the official LazyVim starter template. LazyVim is a Neovim configuration framework that provides a curated set of plugins and sensible defaults.

## Core Architecture

### Directory Structure
- `init.lua` - Entry point that loads the LazyVim configuration
- `lua/config/` - Core configuration files:
  - `lazy.lua` - Bootstrap and configure lazy.nvim plugin manager
  - `autocmds.lua` - Custom autocommands
  - `keymaps.lua` - Custom key mappings
  - `options.lua` - Neovim options and global variables
- `lua/plugins/` - Plugin specifications and customizations
- `lazyvim.json` - LazyVim metadata (extras, version info)
- `lazy-lock.json` - Plugin version lock file

### Plugin Management

LazyVim uses lazy.nvim for plugin management. Plugins are defined in `lua/plugins/` directory. Each file returns a table of plugin specifications.

Key concepts:
- Plugins from LazyVim are automatically loaded via `{ "LazyVim/LazyVim", import = "lazyvim.plugins" }`
- Custom plugins are loaded from `{ import = "plugins" }`
- Plugin specs can override LazyVim defaults by using the same plugin name
- Use `enabled = false` to disable a LazyVim plugin
- Use `opts` to override plugin configuration

## Common Commands

### Neovim Commands
```bash
# Start Neovim (will auto-install plugins on first run)
nvim

# Open plugin manager UI
:Lazy

# Update plugins
:Lazy update

# Check plugin health
:checkhealth
```

### Key Bindings (Default LazyVim)
- `<leader>` is set to `<Space>` by default
- `<leader>l` - Lazy plugin manager commands
- `<leader>e` - File explorer (neo-tree)
- `<leader>ff` - Find files (telescope)
- `<leader>fg` - Live grep (telescope)
- `<leader>fb` - Find buffers (telescope)

### LazyVim Extras
LazyVim provides optional "extras" for language support and features. Enable them by modifying `lazyvim.json` or through the LazyVim UI (`<leader>lx`).

## Development Workflow

### Adding Plugins
Create a new file in `lua/plugins/` or add to existing files:
```lua
return {
  { "plugin/name" },
  -- or with options
  {
    "plugin/name",
    opts = {
      -- configuration
    }
  }
}
```

### Overriding LazyVim Plugins
Use the same plugin name with your custom configuration:
```lua
return {
  {
    "folke/which-key.nvim",
    opts = {
      -- your custom options
    }
  }
}
```

### Disabling LazyVim Plugins
```lua
return {
  { "plugin/name", enabled = false }
}
```

## Important Configuration Variables

- `vim.g.autoformat` - Enable/disable auto-formatting (default: true)
- `vim.g.lazyvim_python_lsp` - Python LSP server choice (default: "pyright", alternative: "basedpyright")
- `vim.g.root_spec` - Root directory detection strategy
- `vim.g.snacks_animate` - Enable/disable UI animations
- `vim.g.lazygit_config` - Auto-configure lazygit theme

## Notes

- This is a starter configuration meant to be customized
- The example plugin file (`lua/plugins/example.lua`) is disabled by default but shows common customization patterns
- Plugin updates are checked periodically (configured in `lua/config/lazy.lua`)
- The configuration uses the Tokyo Night colorscheme by default with Habamax as fallback