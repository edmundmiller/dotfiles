-- Nextflow language support: treesitter parser, LSP, formatter, keybinds
return {
  -- Register Nextflow treesitter parser
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
      parser_config.nextflow = {
        install_info = {
          url = 'https://github.com/nextflow-io/tree-sitter-nextflow',
          files = { 'src/parser.c' },
          branch = 'rewrite',
          generate_requires_npm = false,
        },
        filetype = 'nextflow',
      }
      return opts
    end,
  },

  -- Nextflow LSP via vim.lsp.config (nvim 0.11+)
  {
    'neovim/nvim-lspconfig',
    opts = function()
      vim.lsp.config('nextflow_ls', {
        cmd = { vim.fn.expand '~/.local/share/nvim/mason/packages/nextflow-language-server/nextflow-language-server' },
        filetypes = { 'nextflow' },
        root_markers = { 'nextflow.config', '.git' },
        settings = {
          nextflow = {
            formatting = {
              harshilAlignment = true,
              sortDeclarations = true,
              maheshForm = false,
            },
            errorReportingMode = 'warnings',
            files = {
              exclude = { '.git', '.nf-test', 'work', '.nextflow' },
            },
            completion = {
              extended = true,
              maxItems = 50,
            },
            debug = false,
            languageVersion = '25.04',
            telemetry = { enabled = false },
          },
        },
      })
      vim.lsp.enable 'nextflow_ls'
    end,
  },

  -- Ensure nextflow-language-server is installed via mason
  -- NOTE: use mason package name, not lspconfig name, to avoid lspconfig_to_package mapping
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      table.insert(opts.ensure_installed, 'nextflow-language-server')
    end,
  },

  -- Nextflow formatter via conform
  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.nextflow = { 'nextflow_fmt' }
      opts.formatters = opts.formatters or {}
      opts.formatters.nextflow_fmt = {
        command = 'nextflow',
        args = { 'lint', '-format', '-spaces', '4', '$FILENAME' },
        stdin = false,
        require_cwd = true,
      }
    end,
  },

  -- Nextflow keybinds
  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'nextflow',
        callback = function()
          local wk = require 'which-key'
          wk.add {
            { '<leader>nr', group = 'nextflow run', buffer = true },
            { '<leader>nrr', '<cmd>!nextflow run %<cr>', desc = 'Run script', buffer = true },
            { '<leader>nrl', '<cmd>!nextflow run % -resume<cr>', desc = 'Run with resume', buffer = true },
            { '<leader>nrt', '<cmd>!nf-test test %<cr>', desc = 'Run nf-test', buffer = true },
            { '<leader>nl', group = 'nextflow log', buffer = true },
            { '<leader>nll', '<cmd>!nextflow log<cr>', desc = 'Show log', buffer = true },
            { '<leader>nlc', '<cmd>!nextflow clean -f<cr>', desc = 'Clean work dir', buffer = true },
          }
        end,
      })
      return opts
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
