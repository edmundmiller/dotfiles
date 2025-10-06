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
  - `keymaps.lua` - Custom key mappings (extensive Doom Emacs keybindings)
  - `options.lua` - Neovim options and global variables
- `lua/plugins/` - Plugin specifications and customizations (40+ custom plugin configs)
- `lua/neotest-nftest/` - Custom neotest adapter for Nextflow testing
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

# Sync plugins (clean + update)
:Lazy sync

# Check plugin health
:checkhealth
```

### Key Bindings (Default LazyVim)
- `<leader>` is set to `<Space>` by default
- `<leader>l` - Lazy plugin manager commands
- `<leader>e` - File explorer (snacks-explorer configured)
- `<leader>ff` - Find files (using snacks picker)
- `<leader>fg` - Live grep (using snacks picker)
- `<leader>fb` - Find buffers (using snacks picker)

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

### Options (lua/config/options.lua)
- `vim.g.mapleader = " "` - Leader key is Space
- `vim.g.maplocalleader = "\\"` - Local leader key
- `vim.g.autoformat = true` - Enable/disable auto-formatting (default: true)
- `vim.g.lazyvim_picker = "snacks"` - Use snacks picker instead of telescope (faster)
- `vim.g.snacks_animate = false` - Disable UI animations
- `vim.g.lazyvim_python_lsp` - Python LSP server choice (default: "pyright", alternative: "basedpyright")
- `vim.g.root_spec` - Root directory detection strategy
- `vim.g.lazygit_config` - Auto-configure lazygit theme

### File Type Detection
- `.txt` files in todo/done patterns are detected as `todotxt`
- `.nf` files and `nextflow.config` are detected as `nextflow`
- `.nf.test` files are detected as `nextflow` for test files

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

### AI Assistants

#### Avante.nvim
AI-powered code assistant configured in `lua/plugins/avante.lua`:
- Default provider: Claude (claude-3-5-sonnet-20241022)
- Alternative: OpenAI (gpt-4o)
- Uses snacks input provider
- Token counting enabled
- Diff minimization for cleaner output

#### CodeCompanion.nvim
Alternative AI assistant configured in `lua/plugins/codecompanion.lua`:
- Default adapter: `claude_code` for Claude Code integration
- Supports Claude Code OAuth token (run `claude setup-token`)
- Falls back to Anthropic API key if OAuth not available
- Inline suggestions enabled (Copilot-like experience)

### Custom Plugins
- **claude-code.nvim** - Integration with Claude Code CLI (`lua/plugins/claude-code.lua`)
- **obsidian.nvim** - Note-taking with Obsidian integration (`lua/plugins/obsidian.lua`)
- **orgmode** - Org mode support with GTD workflow (`lua/plugins/orgmode.lua`)
- **snacks.nvim** - Modern UI components (explorer, dashboard, zen mode, picker)
- **git-worktree.nvim** - Git worktree management
- **neogit** - Magit-like git interface
- **vale** - Prose linting integration

### nf-test Testing Framework
A custom neotest adapter for nf-test (Nextflow testing framework) is included:
- **Location**: `lua/neotest-nftest/` and enhanced version in `lua/plugins/neotest-nftest-enhanced.lua`
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

### Snacks.nvim Features
The configuration uses snacks.nvim for modern UI components:
- **File Explorer** (`snacks-explorer.lua`) - Enhanced file browser with git integration
- **Dashboard** (`snacks-dashboard.lua`) - Custom startup screen
- **Zen Mode** (`snacks-zen.lua`) - Distraction-free writing with Ghostty font scaling
- **Picker** (`snacks-picker.lua`) - Fast file/grep picker (default over telescope)
- **Notifier** - Modern notification system
- **Smooth Scrolling** - Animated scrolling (disabled for terminal buffers)

## Notes

- This configuration uses 40+ custom plugin configurations extending LazyVim
- The example plugin file (`lua/plugins/example.lua`) is disabled by default but shows common customization patterns
- Plugin updates are checked periodically (configured in `lua/config/lazy.lua`)
- The configuration uses the Tokyo Night colorscheme by default with Habamax as fallback
- Includes comprehensive Doom Emacs-style keybindings for familiar workflow
- Custom nf-test adapter enables testing of Nextflow pipelines directly from Neovim
- Snacks picker is used as default over telescope for better performance
- Animations are disabled by default for better performance (`vim.g.snacks_animate = false`)