# Neovim

Kickstart-modular with lazy.nvim. Custom plugin specs in `lua/custom/plugins/`
are auto-imported by `lua/lazy-plugins.lua`; runtime config is Nix-managed.

Extension seams:

- conform.nvim: `opts.formatters_by_ft` deep-merges.
- nvim-lint: Kickstart uses `config`, so use `init` + a `FileType` autocmd rather
  than an `opts` merge.
- Treesitter: an `opts` function can call `get_parser_configs()`.
- Neovim 0.11+ LSP: `vim.lsp.config()` + `vim.lsp.enable()`.
- mason-tool-installer takes Mason package names, not lspconfig server names.

Startup smoke check:

```sh
nvim --headless +"lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)"
```

For a filetype change, open a representative file and inspect `vim.bo.filetype`,
`require('conform').list_formatters(0)`, or `require('lint').linters_by_ft`.
