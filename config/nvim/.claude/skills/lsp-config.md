---
skill_name: nvim:lsp-config
description: Configure LSP servers, formatters, and linters in AstroNvim
allowed-tools:
  - Read
  - Edit
  - WebFetch
  - Grep
---

# Configure LSP

Use this skill when the user wants to configure Language Server Protocol (LSP) servers, formatters, linters, or language-specific tooling in their AstroNvim configuration.

## Context

LSP configuration in AstroNvim is centralized in `lua/plugins/astrolsp.lua`. This file handles server-specific settings, keybindings, and capabilities. Tool installation is managed through Mason.

See `.claude/CONTEXT.md` for:

- LSP configuration patterns
- Mason integration
- Server-specific configuration examples

## Your Task

When the user requests LSP configuration:

1. **Understand the requirement**
   - Which language or server?
   - What specific configuration (settings, keybindings, formatting)?
   - Are there external dependencies?

2. **Check existing configuration**
   - Read `lua/plugins/astrolsp.lua` for current server configs
   - Check if language pack exists in `lua/community.lua`
   - Verify if server is already configured

3. **Research server settings**
   - If unfamiliar, fetch LSP server documentation
   - Common sources: nvim-lspconfig docs, language server GitHub
   - Note server-specific setting structures

4. **Configure the server**
   - Add/modify server config in `astrolsp.lua`
   - Configure server settings in appropriate structure
   - Add language-specific keybindings if needed
   - Note Mason installation requirements

5. **Document and explain**
   - Explain what the configuration does
   - Note external tool requirements
   - Suggest testing steps (`:LspInfo`, `:Mason`)

## Configuration Patterns

### Basic Server Configuration

```lua
-- In lua/plugins/astrolsp.lua
return {
  "AstroNvim/astrolsp",
  opts = {
    config = {
      -- Server name from nvim-lspconfig
      pyright = {
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
            },
          },
        },
      },
    },
  },
}
```

### Advanced Server Configuration

```lua
rust_analyzer = {
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures = true,
        loadOutDirsFromCheck = true,
      },
      procMacro = {
        enable = true,
      },
      checkOnSave = {
        command = "clippy",
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Custom on_attach logic
  end,
},
```

### Mason Tool Installation

```lua
-- Ensure LSP server is installed via Mason
-- Can be in astrolsp.lua or separate mason.lua
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

### Formatter/Linter Configuration

```lua
-- Usually via none-ls or conform.nvim
return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      python = { "black", "isort" },
      lua = { "stylua" },
      rust = { "rustfmt" },
    },
  },
}
```

### Language-Specific Keybindings

```lua
-- In astrolsp.lua under mappings
mappings = {
  n = {
    [",r"] = {
      function()
        vim.lsp.buf.code_action()
      end,
      desc = "LSP code action",
      cond = function()
        return vim.bo.filetype == "python"
      end,
    },
  },
},
```

## Common LSP Servers

### Python

- **pyright**: Microsoft's type checker (recommended)
- **pylsp**: Python LSP server
- **ruff_lsp**: Fast linter/formatter
- Settings: `python.analysis.*`

### JavaScript/TypeScript

- **tsserver**: TypeScript language server
- **eslint**: Linting integration
- Settings: `typescript.*`, `javascript.*`

### Rust

- **rust_analyzer**: Primary Rust LSP
- Settings: `["rust-analyzer"].*`
- Common: clippy integration, cargo features

### Go

- **gopls**: Official Go language server
- Settings: `gopls.*`

### Lua

- **lua_ls**: Lua language server (formerly sumneko_lua)
- Settings: `Lua.*`
- Neovim-specific: workspace library setup

## Example Workflows

### Configure Python LSP

**User request**: "Set up pyright for type checking"

**Your response**:

1. Read `lua/plugins/astrolsp.lua` to check existing Python config
2. Check if python pack exists in `lua/community.lua`
3. Add configuration:
   ```lua
   config = {
     pyright = {
       settings = {
         python = {
           analysis = {
             typeCheckingMode = "standard",
             autoSearchPaths = true,
             useLibraryCodeForTypes = true,
           },
         },
       },
     },
   }
   ```
4. Ensure Mason installation: Add `"pyright"` to `ensure_installed`
5. Explain: "Configured pyright with standard type checking. Install with `:Mason` if not already installed."
6. Suggest: "Test with `:LspInfo` in a Python file"

### Add Rust Clippy Integration

**User request**: "Use clippy for Rust linting instead of cargo check"

**Your response**:

1. Read current `rust_analyzer` config in `astrolsp.lua`
2. Modify or add:
   ```lua
   rust_analyzer = {
     settings = {
       ["rust-analyzer"] = {
         checkOnSave = {
           command = "clippy",
         },
       },
     },
   },
   ```
3. Explain: "Changed Rust check command to clippy for enhanced linting"
4. Note: "Requires clippy installed via rustup: `rustup component add clippy`"

### Configure TypeScript with Inlay Hints

**User request**: "Enable inlay hints for TypeScript"

**Your response**:

1. Check `astrolsp.lua` for `tsserver` config
2. Add/modify:
   ```lua
   tsserver = {
     settings = {
       typescript = {
         inlayHints = {
           includeInlayParameterNameHints = "all",
           includeInlayParameterNameHintsWhenArgumentMatchesName = false,
           includeInlayFunctionParameterTypeHints = true,
           includeInlayVariableTypeHints = true,
         },
       },
       javascript = {
         inlayHints = {
           includeInlayParameterNameHints = "all",
         },
       },
     },
   },
   ```
3. Explain the inlay hints settings and what they display

## Important Notes

- **Server names**: Use nvim-lspconfig server names (e.g., `lua_ls` not `lua-language-server`)
- **Settings structure**: Each server has unique settings structure (research if unfamiliar)
- **Mason integration**: Ensure servers are in Mason's `ensure_installed`
- **Testing**: Always suggest `:LspInfo` and `:Mason` for verification
- **External deps**: Note if system packages are needed (e.g., clippy, eslint)
- **Community packs**: Check if AstroCommunity has language pack (includes LSP)

## Advanced Patterns

### Conditional LSP Setup

```lua
config = {
  pyright = {
    root_dir = function(fname)
      local root = require("lspconfig.util").root_pattern("pyproject.toml", "setup.py")(fname)
      return root or vim.fn.getcwd()
    end,
  },
}
```

### Custom Capabilities

```lua
config = {
  tsserver = {
    capabilities = {
      documentFormattingProvider = false,  -- Disable formatting
    },
  },
}
```

### Multiple Servers for Same Language

```lua
-- Use both pyright and ruff_lsp
config = {
  pyright = {
    settings = { python = { analysis = { typeCheckingMode = "standard" } } },
  },
  ruff_lsp = {
    init_options = {
      settings = {
        args = { "--line-length=100" },
      },
    },
  },
}
```

## Related Patterns

- See `/nvim:lsp` slash command for quick LSP setup
- Check `lua/community.lua` for language packs (include LSP)
- See CONTEXT.md for Mason integration patterns
- Research: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
