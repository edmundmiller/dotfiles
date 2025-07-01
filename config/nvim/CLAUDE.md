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

## Custom Features

### Doom Emacs Keybindings
This configuration includes comprehensive Doom Emacs-style keybindings configured in `lua/config/keymaps.lua`. All keybindings use `<Space>` as the leader key and follow Doom's organizational structure:
- `SPC f` - File operations
- `SPC b` - Buffer management  
- `SPC w` - Window management
- `SPC s` - Search operations
- `SPC p` - Project management
- `SPC g` - Git operations
- `SPC t` - Testing and toggles
- `SPC c` - Code operations
- `SPC h` - Help operations

### Custom Plugins
- **claude-code.nvim** - Integration with Claude Code CLI (`lua/plugins/claude-code.lua`)
- **obsidian.nvim** - Note-taking with Obsidian integration (`lua/plugins/obsidian.lua`)
- **neotest-nftest** - Custom adapter for nf-test (Nextflow testing framework)

### nf-test Testing Framework
A custom neotest adapter for nf-test (Nextflow testing framework) is included:
- **Location**: `lua/neotest-nftest/`
- **Test Discovery**: Automatically finds `.nf.test` files and `nextflow_*` test blocks
- **Supported Test Types**: `nextflow_process`, `nextflow_workflow`, `nextflow_pipeline`, `nextflow_function`
- **Key Bindings**:
  - `<leader>tt` - Run nearest test
  - `<leader>tf` - Run file tests  
  - `<leader>ta` - Run all tests
  - `<leader>ts` - Toggle test summary
  - `<leader>tn` - Run with nf-test profile
  - `<leader>td` - Run with debug output

### Testing Commands
```bash
# Prerequisites for nf-test adapter
nf-test --version  # Verify nf-test is installed
nextflow -version  # Verify Nextflow is available

# Initialize nf-test in a project
nf-test init

# Generate test templates
nf-test generate process PROCESS_NAME
nf-test generate workflow WORKFLOW_NAME
```

## Notes

- This is a starter configuration meant to be customized
- The example plugin file (`lua/plugins/example.lua`) is disabled by default but shows common customization patterns
- Plugin updates are checked periodically (configured in `lua/config/lazy.lua`)
- The configuration uses the Tokyo Night colorscheme by default with Habamax as fallback
- Includes comprehensive Doom Emacs-style keybindings for familiar workflow
- Custom nf-test adapter enables testing of Nextflow pipelines directly from Neovim