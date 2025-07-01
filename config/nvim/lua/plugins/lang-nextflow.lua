return {
  -- Nextflow language support
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Add Groovy parser (Nextflow is based on Groovy)
      vim.list_extend(opts.ensure_installed, {
        "groovy",
      })
    end,
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
      ensure_installed = {
        "nextflow_ls",
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
        },
      },
    },
  },

  -- File type detection and basic configuration
  {
    "nvim-treesitter/nvim-treesitter",
    config = function(_, opts)
      -- Setup treesitter
      require("nvim-treesitter.configs").setup(opts)
      
      -- Custom file type detection for Nextflow
      vim.filetype.add({
        extension = {
          nf = "nextflow",
        },
        filename = {
          ["nextflow.config"] = "nextflow",
          ["main.nf"] = "nextflow",
        },
        pattern = {
          ["%.nf%.test"] = "nextflow",
        },
      })
      
      -- Set up Nextflow-specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "nextflow",
        callback = function()
          vim.bo.commentstring = "// %s"
          vim.bo.shiftwidth = 4
          vim.bo.tabstop = 4
          vim.bo.expandtab = true
          
          -- Set up basic syntax highlighting using Groovy
          vim.cmd("runtime! syntax/groovy.vim")
          
          -- Additional Nextflow-specific syntax highlights
          vim.cmd([[
            syntax keyword nextflowKeyword process workflow channel from into
            syntax keyword nextflowKeyword input output script shell exec
            syntax keyword nextflowKeyword when filter map collect
            syntax keyword nextflowKeyword publishDir container
            hi def link nextflowKeyword Keyword
          ]])
        end,
      })
    end,
  },

  -- Formatter support
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        nextflow = { "groovy_format" },
      },
      formatters = {
        groovy_format = {
          command = "npm-groovy-lint",
          args = { "--format", "--stdin" },
          stdin = true,
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
          t({ "process " }), i(1, "PROCESS_NAME"), t({ " {" }),
          t({ "", "    " }), c(2, {
            t("label 'process_low'"),
            t("label 'process_medium'"),
            t("label 'process_high'"),
          }),
          t({ "", "" }),
          t({ "", "    input:" }),
          t({ "", "    " }), i(3, "val meta"),
          t({ "", "    " }), i(4, "path reads"),
          t({ "", "" }),
          t({ "", "    output:" }),
          t({ "", "    " }), i(5, "tuple val(meta), path('*.out')"),
          t({ "", "" }),
          t({ "", "    script:" }),
          t({ "", '    """' }),
          t({ "", "    " }), i(6, "echo 'Processing ${meta.id}'"),
          t({ "", '    """' }),
          t({ "", "}" }),
        }),

        s("workflow", {
          t({ "workflow " }), i(1, "WORKFLOW_NAME"), t({ " {" }),
          t({ "", "    take:" }),
          t({ "", "    " }), i(2, "input_ch"),
          t({ "", "" }),
          t({ "", "    main:" }),
          t({ "", "    " }), i(3, "// workflow logic"),
          t({ "", "" }),
          t({ "", "    emit:" }),
          t({ "", "    " }), i(4, "output_ch"),
          t({ "", "}" }),
        }),

        s("channel", {
          t({ "Channel" }),
          t({ "", "    ." }), c(1, {
            t("from"),
            t("of"),
            t("fromPath"),
            t("fromFilePairs"),
            t("fromSRA"),
          }),
          t({ "(" }), i(2, "data"), t({ ")" }),
        }),

        s("publishDir", {
          t({ "publishDir '" }), i(1, "results"), t({ "', mode: '" }), 
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
}