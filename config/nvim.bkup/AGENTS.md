# AGENTS.md - Quick Reference for LazyVim Configuration

**IMPORTANT: This is a LazyVim configuration. All changes follow LazyVim conventions.**

## Quick Start

```bash
# Test changes immediately (from repo root)
nvim                    # Opens Neovim
:Lazy sync             # Install/update plugins
:checkhealth           # Verify setup
```

## Plugin File Structure

All plugins go in `lua/plugins/`. Each file returns a Lua table:

```lua
-- lua/plugins/your-plugin.lua
return {
  {
    "owner/plugin-name",
    -- Common fields:
    enabled = true,              -- Set false to disable
    lazy = true,                 -- Lazy load by default
    event = "VeryLazy",         -- When to load
    cmd = { "Command" },        -- Load on command
    ft = { "python" },          -- Load on filetype
    keys = {                    -- Load on keymap
      { "<leader>x", "<cmd>Command<cr>", desc = "Description" }
    },
    opts = {                    -- Plugin configuration
      option1 = value,
    },
    config = function(_, opts)  -- Custom setup function
      require("plugin").setup(opts)
    end,
    dependencies = {            -- Required plugins
      "dep/plugin",
    },
  },
}
```

## Common Tasks

### Add a New Plugin
Create `lua/plugins/myplugin.lua`:
```lua
return {
  { "owner/plugin-name" }
}
```

### Override LazyVim Plugin
Use same plugin name with custom opts:
```lua
return {
  {
    "folke/which-key.nvim",  -- Same name as LazyVim's
    opts = { 
      -- Your overrides merge with LazyVim defaults
    }
  }
}
```

### Disable LazyVim Plugin
```lua
return {
  { "plugin/name", enabled = false }
}
```

### Modify Existing Plugin Config
Use `opts` function to modify:
```lua
return {
  {
    "plugin/name",
    opts = function(_, opts)
      opts.new_option = true
      return opts
    end,
  }
}
```

## Current Configuration

### Enabled LazyVim Extras
- **Coding**: luasnip, mini-comment, mini-surround, yanky
- **Editor**: harpoon2, inc-rename, snacks_picker
- **Lang**: docker, git, json, markdown, python, sql, terraform, yaml
- **Test**: core (neotest framework)
- **UI**: smear-cursor, treesitter-context
- **Util**: dot, mini-hipatterns, octo, project

### Custom Features
- **Doom Emacs keybindings** in most plugins (SPC leader)
- **Custom plugins**: claude-code, obsidian, database, git-workflow
- **Colorscheme**: Catppuccin (latte/light)
- **Disabled**: Default dashboard, alpha

### Key Patterns in This Config
1. Most plugins use Doom-style keybindings (`<leader>` = Space)
2. Git plugins extensively customized (fugitive, worktree, workflow)
3. Database support via vim-dadbod
4. AI assistance via codecompanion and claude-code

## LazyVim Specifics

### Plugin Loading Order
1. LazyVim core plugins (`lazyvim.plugins`)
2. LazyVim extras (from `lazyvim.json`)
3. Your plugins (`lua/plugins/`)

### Important Variables
- `vim.g.mapleader = " "` (Space as leader)
- `vim.g.autoformat` - Auto-formatting toggle
- `vim.g.lazyvim_python_lsp` - Python LSP choice

### Testing Changes
```vim
:Lazy reload plugin-name  " Reload specific plugin
:Lazy profile            " Check startup time
:Lazy debug              " Debug plugin issues
```

## Quick Links
- LazyVim Docs: http://www.lazyvim.org
- Configuration: http://www.lazyvim.org/configuration
- Keymaps: http://www.lazyvim.org/keymaps
- Plugins: http://www.lazyvim.org/plugins

## Tips for Fast Edits

1. **Check existing patterns**: Look at similar plugins in `lua/plugins/`
2. **Use opts for config**: Prefer `opts` over `config` function
3. **Test incrementally**: `:Lazy reload` after each change
4. **Follow conventions**: Match existing code style (2-space indent, trailing commas)
5. **Check health**: Run `:checkhealth` after major changes

## Common Gotchas

- Don't modify `lazy-lock.json` directly (auto-generated)
- Use `enabled = false` not deleting to disable plugins
- LazyVim plugins can be overridden by name matching
- Some plugins need `lazy = false` to work properly
- Dependencies auto-install but check versions in lock file