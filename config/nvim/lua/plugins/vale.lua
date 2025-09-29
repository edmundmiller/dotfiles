return {
  -- Ensure vale-ls is installed via Mason
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "vale-ls" })
      return opts
    end,
  },

  -- Configure vale-ls with nvim-lspconfig
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vale_ls = {
          filetypes = { "markdown", "tex", "text", "rst", "asciidoc", "org" },
          -- Vale configuration
          init_options = {
            -- Path to .vale.ini config (will look in project root by default)
            -- Uncomment to use a global config:
            -- configPath = vim.fn.expand("~/.config/vale/.vale.ini"),
            -- Sync on startup
            syncOnStartup = true,
          },
          settings = {
            vale = {
              -- Enable/disable Vale
              enabled = true,
            },
          },
        },
      },
    },
  },
}