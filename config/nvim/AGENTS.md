# Neovim Config

Kickstart-modular config with custom plugin layer.

## History

Previous config was AstroNvim with ~40 plugin files, custom nextflow tooling, snippets, and a separate kickstart fork. All removed in `a1b69cb3`. Reference that commit for anything that needs to be recovered.

## Structure

```
config/nvim/
├── init.lua              # Entry point (bootstraps lazy.nvim)
├── lua/options.lua       # Vim options
├── lua/keymaps.lua       # Global keymaps
├── lua/lazy-bootstrap.lua
├── lua/lazy-plugins.lua  # Plugin imports
├── lua/kickstart/        # Kickstart modules (health, lsp, treesitter, etc.)
└── lua/custom/plugins/   # Custom plugin specs (auto-imported)
```

## Managed by Nix

This directory is symlinked from the Nix store — **read-only at runtime**. Edit source files here, then `hey rebuild`.

## Adding custom plugins

Drop a `.lua` file in `lua/custom/plugins/`. It's auto-imported via `{ import = 'custom.plugins' }` in `lazy-plugins.lua`.

### Extending kickstart plugins

- **conform.nvim**: Use `opts = { formatters_by_ft = { ... } }` — lazy.nvim deep-merges tables.
- **nvim-lint**: Uses `config` not `opts`, so you can't merge. Use `init` + `FileType` autocmd to register linters after kickstart's config runs.
- **treesitter**: Use `opts` function to call `get_parser_configs()`.
- **lspconfig**: Use `vim.lsp.config()` + `vim.lsp.enable()` (nvim 0.11+, NOT deprecated `require('lspconfig')`).
- **mason-tool-installer**: Use mason package names directly (e.g. `nextflow-language-server`), NOT lspconfig server names — avoids `lspconfig_to_package` mapping errors.

## Headless testing

```bash
# No startup errors
nvim --headless +"lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)" 2>&1

# Filetype detection
nvim --headless /tmp/test.nf +"lua vim.defer_fn(function() print('ft=' .. vim.bo.filetype) vim.cmd('qa!') end, 5000)" 2>&1

# Registered formatters for current buffer
nvim --headless /tmp/test.nf +"lua vim.defer_fn(function() local c = require('conform') for _, f in ipairs(c.list_formatters(0)) do print(f.name .. ' available=' .. tostring(f.available)) end vim.cmd('qa!') end, 5000)" 2>&1

# Registered linters for current buffer
nvim --headless /tmp/test.nf +"lua vim.defer_fn(function() local l = require('lint') print(vim.inspect(l.linters_by_ft[vim.bo.filetype])) vim.cmd('qa!') end, 5000)" 2>&1
```
