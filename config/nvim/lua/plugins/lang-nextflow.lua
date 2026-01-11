-- Nextflow language support
return {
  -- Treesitter configuration for Nextflow
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = function(_, opts)
      -- Register the Nextflow parser with rewrite branch
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.nextflow = {
        install_info = {
          url = "https://github.com/nextflow-io/tree-sitter-nextflow",
          files = { "src/parser.c" },
          branch = "rewrite",
          generate_requires_npm = false,
        },
        filetype = "nextflow",
      }
      
      return opts
    end,
  },

  -- Mason LSP configuration
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "nextflow-language-server",
      },
    },
  },

  -- LSP configuration for Nextflow
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nextflow_ls = {
          cmd = { vim.fn.expand("~/.local/share/nvim/mason/packages/nextflow-language-server/nextflow-language-server") },
          filetypes = { "nextflow" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("nextflow.config", ".git")(fname)
          end,
          settings = {
            nextflow = {
              -- Formatting preferences
              formatting = {
                harshilAlignment = true,
                sortDeclarations = true,
                maheshForm = false,
              },
              -- Error reporting level
              errorReportingMode = "warnings",
              -- File exclusions
              files = {
                exclude = { ".git", ".nf-test", "work", ".nextflow" },
              },
              -- Completion settings
              completion = {
                extended = true,
                maxItems = 50,
              },
              -- Debug mode
              debug = false,
              -- Language version
              languageVersion = "25.04",
              -- Telemetry
              telemetry = {
                enabled = false,
              },
            },
          },
        },
      },
    },
  },

  -- Formatter support
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        nextflow = { "nextflow_lint" },
      },
      formatters = {
        nextflow_lint = {
          command = "nextflow",
          args = { "lint", "-format", "-spaces", "4", "$FILENAME" },
          stdin = false,
          require_cwd = true,
        },
      },
    },
  },

  -- Enhanced file explorer support
  {
    "nvim-tree/nvim-web-devicons",
    opts = {
      override_by_extension = {
        ["nf"] = {
          icon = "🔬",
          color = "#4CAF50",
          cterm_color = "34",
          name = "Nextflow",
        },
      },
      override_by_filename = {
        ["nextflow.config"] = {
          icon = "⚙️",
          color = "#FFA726",
          cterm_color = "214",
          name = "NextflowConfig",
        },
        ["main.nf"] = {
          icon = "🚀",
          color = "#42A5F5",
          cterm_color = "75",
          name = "NextflowMain",
        },
      },
    },
  },

  -- Nextflow-specific keybindings
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      -- Set up nextflow keymaps in autocmd for filetype-specific bindings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "nextflow",
        callback = function()
          local wk = require("which-key")
          wk.add({
            { "<leader>nr", group = "nextflow run", buffer = true },
            {
              "<leader>nrr",
              "<cmd>!nextflow run %<cr>",
              desc = "Run current Nextflow script",
              buffer = true,
            },
            {
              "<leader>nrl",
              "<cmd>!nextflow run % -resume<cr>",
              desc = "Run with resume",
              buffer = true,
            },
            {
              "<leader>nrt",
              "<cmd>!nf-test test %<cr>",
              desc = "Run nf-test on current file",
              buffer = true,
            },
            { "<leader>nl", group = "nextflow log", buffer = true },
            {
              "<leader>nll",
              "<cmd>!nextflow log<cr>",
              desc = "Show Nextflow log",
              buffer = true,
            },
            {
              "<leader>nlc",
              "<cmd>!nextflow clean -f<cr>",
              desc = "Clean work directory",
              buffer = true,
            },
          })
        end,
      })
      return opts
    end,
  },
}