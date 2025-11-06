-- Ghostty terminal configuration support
return {
  -- Treesitter configuration for Ghostty
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = function(_, opts)
      -- Ensure opts.ensure_installed exists
      opts.ensure_installed = opts.ensure_installed or {}

      -- Register custom parser for ghostty BEFORE adding to ensure_installed
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.ghostty = {
        install_info = {
          url = "https://github.com/bezhermoso/tree-sitter-ghostty",
          files = { "src/parser.c" },
          branch = "main",
          generate_requires_npm = false,
          requires_generate_from_grammar = false,
        },
        filetype = "ghostty",
      }

      -- Now add ghostty to ensure_installed (will auto-install on startup)
      vim.list_extend(opts.ensure_installed, { "ghostty" })

      return opts
    end,
    config = function(_, opts)
      -- Setup treesitter with opts (includes ensure_installed)
      require("nvim-treesitter.configs").setup(opts)

      -- Register filetype for ghostty
      vim.filetype.add({
        pattern = {
          [".*ghostty/config"] = "ghostty",
        },
      })

      -- Register language for treesitter
      vim.treesitter.language.register("ghostty", "ghostty")
    end,
  },

  -- Mason LSP configuration
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "ghostty-ls",
      })
      return opts
    end,
  },

  -- LSP configuration for Ghostty
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ghostty = {
          cmd = { "ghostty-ls" },
          filetypes = { "ghostty" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern(".git")(fname) or vim.fn.fnamemodify(fname, ":h")
          end,
        },
      },
    },
  },

  -- Ghostty config validator
  {
    "isak102/ghostty.nvim",
    ft = "ghostty",
    opts = {
      file_pattern = "*/ghostty/config",
      ghostty_cmd = "ghostty",
      check_timeout = 1000,
    },
  },

  -- Theme synchronization between Neovim and Ghostty
  {
    "landerson02/ghostty-theme-sync.nvim",
    opts = {
      ghostty_config_path = vim.fn.expand("~/.config/ghostty/config"),
      persist_nvim_theme = false,
      nvim_config_path = "",
    },
  },

  -- Enhanced file explorer support
  {
    "nvim-tree/nvim-web-devicons",
    opts = {
      override_by_filename = {
        ["config"] = {
          icon = "👻",
          color = "#A78BFA",
          cterm_color = "141",
          name = "GhosttyConfig",
        },
      },
    },
  },

  -- Ghostty-specific keybindings
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      -- Set up ghostty keymaps in autocmd for filetype-specific bindings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "ghostty",
        callback = function()
          local wk = require("which-key")
          wk.add({
            { "<leader>g", group = "ghostty", buffer = true },
            {
              "<leader>gt",
              "<cmd>GhosttyTheme<cr>",
              desc = "Select Ghostty theme",
              buffer = true,
            },
            {
              "<leader>gv",
              function()
                require("ghostty").validate()
              end,
              desc = "Validate Ghostty config",
              buffer = true,
            },
          })
        end,
      })
      return opts
    end,
  },
}
