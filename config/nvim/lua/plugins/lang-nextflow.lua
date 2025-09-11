-- Nextflow language support
return {
  -- Treesitter configuration for Nextflow
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = { "groovy" }, -- Groovy for fallback, nextflow will be installed manually
    },
  },

  -- Mason LSP configuration
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "nextflow-language-server",
      },
    },
  },

  -- Mason LSP Config
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      handlers = {
        nextflow_ls = function()
          require("lspconfig").nextflow_ls.setup({})
        end,
      },
    },
  },

  -- LSP configuration for Nextflow
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Use official Nextflow Language Server
        nextflow_ls = {
          filetypes = { "nextflow" },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("nextflow.config", ".git")(fname)
          end,
          settings = {
            nextflow = {
              -- Formatting preferences
              formatting = {
                harshilAlignment = true, -- Use Harshil Alignment for better formatting
                sortDeclarations = true, -- Sort script declarations
                maheshForm = false, -- Keep default process output placement
              },
              -- Error reporting level
              errorReportingMode = "warnings",
              -- File exclusions
              files = {
                exclude = { ".git", ".nf-test", "work", ".nextflow" },
              },
              -- Completion settings
              completion = {
                extended = true, -- Enable extended completions from outside current script
                maxItems = 50, -- Reasonable limit for suggestions
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

  -- Snippets for Nextflow
  {
    "L3MON4D3/LuaSnip",
    config = function()
      local ls = require("luasnip")
      local s = ls.snippet
      local t = ls.text_node
      local i = ls.insert_node
      local c = ls.choice_node

      ls.add_snippets("nextflow", {
        s("process", {
          t({ "process " }),
          i(1, "PROCESS_NAME"),
          t({ " {" }),
          t({ "", "    " }),
          c(2, {
            t("label 'process_low'"),
            t("label 'process_medium'"),
            t("label 'process_high'"),
          }),
          t({ "", "" }),
          t({ "", "    input:" }),
          t({ "", "    " }),
          i(3, "val meta"),
          t({ "", "    " }),
          i(4, "path reads"),
          t({ "", "" }),
          t({ "", "    output:" }),
          t({ "", "    " }),
          i(5, "tuple val(meta), path('*.out')"),
          t({ "", "" }),
          t({ "", "    script:" }),
          t({ "", '    """' }),
          t({ "", "    " }),
          i(6, "echo 'Processing ${meta.id}'"),
          t({ "", '    """' }),
          t({ "", "}" }),
        }),

        s("workflow", {
          t({ "workflow " }),
          i(1, "WORKFLOW_NAME"),
          t({ " {" }),
          t({ "", "    take:" }),
          t({ "", "    " }),
          i(2, "input_ch"),
          t({ "", "" }),
          t({ "", "    main:" }),
          t({ "", "    " }),
          i(3, "// workflow logic"),
          t({ "", "" }),
          t({ "", "    emit:" }),
          t({ "", "    " }),
          i(4, "output_ch"),
          t({ "", "}" }),
        }),

        s("channel", {
          t({ "Channel" }),
          t({ "", "    ." }),
          c(1, {
            t("from"),
            t("of"),
            t("fromPath"),
            t("fromFilePairs"),
            t("fromSRA"),
          }),
          t({ "(" }),
          i(2, "data"),
          t({ ")" }),
        }),

        s("publishDir", {
          t({ "publishDir '" }),
          i(1, "results"),
          t({ "', mode: '" }),
          c(2, {
            t("copy"),
            t("symlink"),
            t("move"),
            t("link"),
          }),
          t({ "'" }),
        }),
      })
    end,
  },

  -- Additional Nextflow-specific keybindings (optional compilation commands)
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