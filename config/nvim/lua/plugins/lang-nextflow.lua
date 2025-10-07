-- Nextflow language support for AstroNvim
-- Provides treesitter, LSP, formatting, and keybindings for Nextflow development

---@type LazySpec
return {
  -- Treesitter configuration for Nextflow
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Add nextflow to ensure_installed
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "nextflow" })
    end,
    config = function(plugin, opts)
      -- Call the default AstroNvim treesitter config
      require("astronvim.plugins.configs.nvim-treesitter")(plugin, opts)

      -- Register filetype for nextflow
      vim.filetype.add({
        extension = {
          nf = "nextflow",
        },
        pattern = {
          [".*%.nextflow"] = "nextflow",
        },
      })

      -- Register language for treesitter
      vim.treesitter.language.register("nextflow", "nextflow")
    end,
  },

  -- Mason tool installer for nextflow-language-server
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
        "nextflow-language-server",
      })
    end,
  },

  -- LSP configuration for Nextflow
  {
    "AstroNvim/astrolsp",
    opts = {
      config = {
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
    "AstroNvim/astrocore",
    opts = function(_, opts)
      -- Create autocmd for Nextflow-specific keybindings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "nextflow",
        callback = function(args)
          local bufnr = args.buf
          local maps = require("astrocore").empty_map_table()

          -- Nextflow run commands
          maps.n["<Leader>nr"] = { desc = "Nextflow run" }
          maps.n["<Leader>nrr"] = { "<Cmd>!nextflow run %<CR>", desc = "Run current Nextflow script" }
          maps.n["<Leader>nrl"] = { "<Cmd>!nextflow run % -resume<CR>", desc = "Run with resume" }
          maps.n["<Leader>nrt"] = { "<Cmd>!nf-test test %<CR>", desc = "Run nf-test on current file" }

          -- Nextflow log commands
          maps.n["<Leader>nl"] = { desc = "Nextflow log" }
          maps.n["<Leader>nll"] = { "<Cmd>!nextflow log<CR>", desc = "Show Nextflow log" }
          maps.n["<Leader>nlc"] = { "<Cmd>!nextflow clean -f<CR>", desc = "Clean work directory" }

          require("astrocore").set_mappings(maps, { buffer = bufnr })
        end,
      })
    end,
  },
}
