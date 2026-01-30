# AstroNvim Configuration Context

This context file provides Claude Code with patterns, templates, and conventions for working with this AstroNvim v5 configuration.

## Configuration Overview

**Framework**: AstroNvim v5 with Lazy.nvim plugin manager
**Style**: Doom Emacs-inspired keybindings with mnemonic prefixes
**Organization**: Modular plugin files + AstroCommunity imports

### Directory Structure

```
config/nvim/
├── init.lua                    # Bootstrap Lazy.nvim
├── lua/
│   ├── lazy_setup.lua         # Main Lazy.nvim config
│   ├── community.lua          # AstroCommunity imports
│   ├── polish.lua             # Final setup hooks
│   └── plugins/               # Individual plugin configs
│       ├── astrocore.lua     # Core: mappings, options, autocommands
│       ├── astroui.lua       # UI configuration
│       ├── astrolsp.lua      # LSP configuration
│       └── *.lua             # Individual plugin configs
├── snippets/                  # Custom snippets
└── .claude/                   # This configuration
```

## Plugin File Templates

### Standard Plugin Template

```lua
---@type LazySpec
return {
  "author/plugin-name",
  dependencies = {
    "dependency/plugin",
  },
  cmd = { "PluginCommand" },  -- Lazy load on command
  keys = {  -- Lazy load on keybinding
    { "<leader>xy", "<cmd>PluginCommand<cr>", desc = "Description" },
  },
  ft = { "filetype" },  -- Lazy load on filetype
  opts = {
    -- Plugin options here
  },
  config = function(_, opts)
    -- Advanced setup if needed
    require("plugin").setup(opts)
  end,
}
```

### Extended Plugin Template (with documentation)

```lua
-- Plugin Name
-- https://github.com/author/plugin-name
--
-- Brief description of what this plugin does and why it's useful.
-- Explain how it fits into the overall workflow.
--
-- Key features:
-- - Feature 1
-- - Feature 2
-- - Feature 3
--
-- Complements: other-plugin, another-plugin

---@type LazySpec
return {
  "author/plugin-name",
  dependencies = {
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = {
          ["<Leader>x"] = { name = "Plugin Prefix" },
          ["<Leader>xa"] = { "<cmd>PluginAction<cr>", desc = "Action description" },
        },
      },
    },
  },
  cmd = { "PluginCommand" },
  keys = {
    { "<Leader>xa", "<cmd>PluginAction<cr>", desc = "Action description" },
  },
  opts = {
    -- Configuration options
  },
}
```

### Local Development Plugin Template

```lua
---@type LazySpec
return {
  "username/plugin-name",
  dev = true,  -- Load from ~/src/emacs/ if available
  dependencies = { "other/plugin" },
  config = function()
    require("plugin-name").setup({
      -- options
    })
  end,
}
```

### Local Directory Plugin Template

```lua
---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/lua/plugin-implementation",
  name = "plugin-name",
  dependencies = { "other/plugin" },
  config = function()
    -- Setup code
  end,
}
```

## Keybinding Organization

### Leader Key Prefixes (Doom Emacs Style)

| Prefix      | Category     | Examples                              |
| ----------- | ------------ | ------------------------------------- |
| `<leader>f` | Files        | `ff` find, `fr` recent, `fw` grep     |
| `<leader>s` | Search       | `ss` buffer, `sp` project, `sh` help  |
| `<leader>b` | Buffers      | `bb` list, `bd` delete, `bn` next     |
| `<leader>w` | Windows      | `ww` other, `ws` split, `wv` vsplit   |
| `<leader>g` | Git          | `gg` status, `gc` commit, `gl` log    |
| `<leader>c` | Code         | `ca` action, `cr` rename, `cf` format |
| `<leader>t` | Toggle       | `tn` numbers, `ts` spell, `tw` wrap   |
| `<leader>q` | Quit         | `qq` quit, `qQ` quit all              |
| `<leader>h` | Help         | `hh` help, `hm` man                   |
| `<leader>j` | Jujutsu (JJ) | `jj` status, `jc` commit, `jl` log    |
| `<leader>n` | Notes/Tools  | `nr` nextflow runner                  |
| `,` (local) | Language     | LSP, testing, language-specific       |

### Keybinding Template (in astrocore.lua)

```lua
-- In lua/plugins/astrocore.lua under mappings = { n = { ... } }
["<Leader>x"] = { name = "Category Name" },  -- Which-key group
["<Leader>xa"] = { "<cmd>Command<cr>", desc = "Action description" },
["<Leader>xb"] = { function() vim.cmd("Command") end, desc = "Action with function" },
```

### Plugin-Specific Keybindings

```lua
-- In individual plugin file
keys = {
  { "<Leader>xa", "<cmd>Command<cr>", desc = "Action description" },
  { "<Leader>xb", function() require("plugin").action() end, desc = "Lua function action" },
},
```

## AstroCommunity Integration

### Community Import Pattern

```lua
-- In lua/community.lua
return {
  -- Category: pack-name
  { import = "astrocommunity.category.pack-name" },

  -- Can be customized in lua/plugins/user.lua
}
```

### Major AstroCommunity Categories

**Completion**

- `completion.codeium-vim`, `completion.copilot-lua-cmp`

**Editing Support**

- `editing-support.comment-box-nvim`, `editing-support.multiple-cursors-nvim`
- `editing-support.refactoring-nvim`, `editing-support.vim-move`

**Git Integration**

- `git.blame-nvim`, `git.diffview-nvim`, `git.fugit2-nvim`
- `git.git-blame-nvim`, `git.neogit`, `git.octo-nvim`

**Language Packs** (88 total)

- `pack.bash`, `pack.python`, `pack.rust`, `pack.typescript`
- `pack.go`, `pack.lua`, `pack.markdown`, `pack.yaml`
- Custom: `pack.nextflow` (if exists)

**Motion**

- `motion.flash-nvim`, `motion.leap-nvim`, `motion.mini-move`

**Note Taking**

- `note-taking.neorg`, `note-taking.obsidian-nvim`, `note-taking.vimwiki`

**Syntax**

- `syntax.vim-sandwich`, `syntax.vim-easy-align`

**Test**

- `test.neotest`, `test.nvim-coverage`

**Workflow**

- `workflow.hardtime-nvim`, `workflow.precognition-nvim`

### Customizing Community Packs

```lua
-- In lua/plugins/user.lua
return {
  {
    "AstroNvim/astrocommunity",
    { import = "astrocommunity.colorscheme.catppuccin" },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = function(_, opts)
      opts.flavour = "latte"  -- Custom option
      return opts
    end,
  },
}
```

## LSP Configuration

### LSP Server Configuration (in astrolsp.lua)

```lua
-- In lua/plugins/astrolsp.lua
return {
  "AstroNvim/astrolsp",
  opts = {
    config = {
      -- Server-specific configuration
      tsserver = {
        settings = {
          typescript = {
            inlayHints = {
              includeInlayParameterNameHints = "all",
            },
          },
        },
      },
      rust_analyzer = {
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = {
              command = "clippy",
            },
          },
        },
      },
    },
  },
}
```

### Mason Tool Installation

```lua
-- In lua/plugins/mason.lua or astrolsp.lua
return {
  "williamboman/mason-lspconfig.nvim",
  opts = {
    ensure_installed = {
      "lua_ls",
      "pyright",
      "rust_analyzer",
      "tsserver",
    },
  },
}
```

## Common Patterns

### 1. Telescope Integration

Most discovery/selection uses Telescope:

```lua
keys = {
  {
    "<Leader>fa",
    function()
      require("telescope.builtin").find_files()
    end,
    desc = "Find files",
  },
}
```

### 2. Which-key Registration

Register key groups for discoverability:

```lua
dependencies = {
  "AstroNvim/astrocore",
  opts = {
    mappings = {
      n = {
        ["<Leader>x"] = { name = "Category Name" },
      },
    },
  },
},
```

### 3. AutoCommands

Common pattern for FileType-specific setup:

```lua
{
  "AstroNvim/astrocore",
  opts = {
    autocmds = {
      plugin_name = {
        {
          event = "FileType",
          pattern = "filetype",
          callback = function()
            -- Setup code
          end,
        },
      },
    },
  },
}
```

### 4. User Commands

Define commands for non-keybinding access:

```lua
{
  "AstroNvim/astrocore",
  opts = {
    commands = {
      PluginCommand = {
        function()
          -- Command implementation
        end,
        desc = "Command description",
      },
    },
  },
}
```

### 5. Lazy Loading Strategies

**By command**: `cmd = { "CommandName" }`
**By keybinding**: `keys = { { "<Leader>xy", ... } }`
**By filetype**: `ft = { "python", "lua" }`
**By event**: `event = "VeryLazy"`
**Development mode**: `dev = true` (loads from `~/src/emacs/username/plugin`)

## Development Workflow

### Adding a Plugin

1. Create `lua/plugins/plugin-name.lua`
2. Add plugin specification with lazy-loading
3. Configure keybindings (prefer plugin-local `keys = {}`)
4. Add which-key group if needed
5. Document purpose and integration

### Adding Community Pack

1. Add import to `lua/community.lua`
2. (Optional) Customize in `lua/plugins/user.lua`
3. Verify no conflicts with existing plugins

### Managing Keybindings

1. Check `lua/plugins/astrocore.lua` for existing prefixes
2. Add to plugin-local `keys = {}` if plugin-specific
3. Add to `astrocore.lua` mappings if global
4. Always include `desc` for which-key

### Configuring LSP

1. Add server config to `lua/plugins/astrolsp.lua`
2. Ensure server installed via Mason
3. Add language-specific keybindings under `,` (local leader)
4. Test with `:LspInfo` and `:Mason`

## Best Practices

1. **Documentation First**: Add header comments explaining purpose
2. **Lazy Loading**: Use `cmd`, `keys`, `ft`, `event` to defer loading
3. **Mnemonic Keys**: Follow Doom Emacs prefix conventions
4. **Which-key Integration**: Always register key groups
5. **One Plugin Per File**: Keep plugins modular (except related suites like JJ)
6. **Complementary Tools**: Document how plugins work together
7. **Local Development**: Use `dev = true` for plugins in development

## References

- **AstroNvim Docs**: https://docs.astronvim.com/
- **AstroCommunity**: https://astronvim.github.io/astrocommunity/
- **Lazy.nvim**: https://github.com/folke/lazy.nvim
- **Which-key**: Automatic keybinding hints
- **Mason**: LSP/tool installer integration
