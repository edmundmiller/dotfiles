return {
  -- Typst language support via typst.vim
  {
    "kaarmu/typst.vim",
    ft = "typst",
    config = function()
      -- Typst-specific settings
      vim.g.typst_pdf_viewer = "skim"  -- Change to your preferred PDF viewer
      vim.g.typst_conceal = 1  -- Enable symbol concealing
      vim.g.typst_auto_open_quickfix = 1  -- Auto-open quickfix for errors
      
      -- Enable embedded language highlighting
      vim.g.typst_embedded_languages = {
        "python",
        "rust", 
        "javascript",
        "bash",
        "c",
        "cpp",
        "lua",
      }
    end,
  },

  -- Treesitter support (work in progress - fallback to basic vim syntax)
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Check if typst parser is available
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      if parser_config.typst then
        vim.list_extend(opts.ensure_installed, { "typst" })
      end
    end,
  },

  -- LSP support via tinymist
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tinymist = {
          single_file_support = true,
          settings = {
            exportPdf = "onType",  -- Export PDF on type, save, or never
            outputPath = "$root/target/$dir/$name",
          },
        },
      },
    },
  },

  -- Mason support for installing tinymist
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "tinymist" })
      return opts
    end,
  },

  -- File type and basic configuration
  {
    "nvim-treesitter/nvim-treesitter",
    config = function(_, opts)
      -- Setup treesitter
      require("nvim-treesitter.configs").setup(opts)
      
      -- Enhanced file type detection
      vim.filetype.add({
        extension = {
          typ = "typst",
        },
        pattern = {
          ["%.typst"] = "typst",
        },
      })
      
      -- Typst-specific autocmds
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "typst",
        callback = function()
          -- Editor settings
          vim.bo.commentstring = "// %s"
          vim.bo.shiftwidth = 2
          vim.bo.tabstop = 2
          vim.bo.expandtab = true
          vim.wo.wrap = true
          vim.wo.linebreak = true
          vim.bo.textwidth = 80
          
          -- Enable spell checking for Typst documents
          vim.wo.spell = true
          vim.opt_local.spelllang = "en_us"
          
          -- Set up folding
          vim.wo.foldmethod = "expr"
          vim.wo.foldexpr = "nvim_treesitter#foldexpr()"
          vim.wo.foldenable = true
          vim.wo.foldlevel = 99
        end,
      })
    end,
  },

  -- Formatter support
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.typst = { "typstfmt" }
      
      opts.formatters = opts.formatters or {}
      opts.formatters.typstfmt = {
        command = "typstfmt",
        args = { "--stdin" },
        stdin = true,
      }
      return opts
    end,
  },

  -- Enhanced file explorer support
  {
    "nvim-tree/nvim-web-devicons",
    opts = function(_, opts)
      opts.override_by_extension = opts.override_by_extension or {}
      opts.override_by_extension["typ"] = {
        icon = "📄",
        color = "#239DAD",
        cterm_color = "31",
        name = "Typst",
      }
      opts.override_by_extension["typst"] = {
        icon = "📝",
        color = "#239DAD", 
        cterm_color = "31",
        name = "Typst",
      }
      return opts
    end,
  },

  -- Snippets for Typst
  {
    "L3MON4D3/LuaSnip",
    config = function()
      local ls = require("luasnip")
      local s = ls.snippet
      local t = ls.text_node
      local i = ls.insert_node
      local c = ls.choice_node
      local f = ls.function_node

      ls.add_snippets("typst", {
        -- Document setup
        s("doc", {
          t({ "#set document(" }),
          t({ "", '  title: "' }), i(1, "Document Title"), t({ '",' }),
          t({ "", '  author: "' }), i(2, "Author Name"), t({ '",' }),
          t({ "", '  date: ' }), f(function() return "datetime.today()" end), t({ "," }),
          t({ "", ")" }),
          t({ "", "" }),
          t({ "", "#set page(" }),
          t({ "", "  paper: " }), c(3, { t('"a4"'), t('"us-letter"'), t('"a3"') }), t({ "," }),
          t({ "", "  margin: " }), i(4, "1in"), t({ "," }),
          t({ "", ")" }),
          t({ "", "" }),
          t({ "", "#set text(" }),
          t({ "", "  font: " }), c(5, { t('"Linux Libertine"'), t('"Times New Roman"'), t('"Arial"') }), t({ "," }),
          t({ "", "  size: " }), i(6, "11pt"), t({ "," }),
          t({ "", ")" }),
          t({ "", "" }),
          i(0),
        }),

        -- Heading
        s("h1", {
          t({ "= " }), i(1, "Heading"),
        }),
        s("h2", {
          t({ "== " }), i(1, "Heading"),
        }),
        s("h3", {
          t({ "=== " }), i(1, "Heading"),
        }),

        -- Text formatting
        s("bold", {
          t({ "*" }), i(1, "bold text"), t({ "*" }),
        }),
        s("italic", {
          t({ "_" }), i(1, "italic text"), t({ "_" }),
        }),
        s("code", {
          t({ "`" }), i(1, "code"), t({ "`" }),
        }),

        -- Math
        s("math", {
          t({ "$" }), i(1, "x = y"), t({ "$" }),
        }),
        s("equation", {
          t({ "$ " }), i(1, "equation"), t({ " $" }),
        }),

        -- Lists
        s("list", {
          t({ "- " }), i(1, "Item 1"),
          t({ "", "- " }), i(2, "Item 2"),
          t({ "", "- " }), i(3, "Item 3"),
        }),
        s("enum", {
          t({ "+ " }), i(1, "Item 1"),
          t({ "", "+ " }), i(2, "Item 2"),
          t({ "", "+ " }), i(3, "Item 3"),
        }),

        -- Figures
        s("figure", {
          t({ "#figure(" }),
          t({ "", "  image(" }), i(1, '"path/to/image.png"'), t({ ")," }),
          t({ "", '  caption: [' }), i(2, "Caption"), t({ "]," }),
          t({ "", ") " }), i(3, "<label>"),
        }),

        -- Table
        s("table", {
          t({ "#table(" }),
          t({ "", "  columns: " }), i(1, "3"), t({ "," }),
          t({ "", "  [*Header 1*], [*Header 2*], [*Header 3*]," }),
          t({ "", "  [" }), i(2, "Cell 1"), t({ "], [" }), i(3, "Cell 2"), t({ "], [" }), i(4, "Cell 3"), t({ "]," }),
          t({ "", ")" }),
        }),

        -- Code block
        s("code_block", {
          t({ "```" }), i(1, "python"),
          t({ "", "" }), i(2, "# Your code here"),
          t({ "", "```" }),
        }),

        -- Link
        s("link", {
          t({ "#link(" }), i(1, '"https://example.com"'), t({ ")[" }), i(2, "Link text"), t({ "]" }),
        }),

        -- Citation
        s("cite", {
          t({ "@" }), i(1, "citation_key"),
        }),

        -- Bibliography
        s("bibliography", {
          t({ '#bibliography("' }), i(1, "references.bib"), t({ '")' }),
        }),

        -- Page break
        s("pagebreak", {
          t({ "#pagebreak()" }),
        }),

        -- Function definition
        s("func", {
          t({ "#let " }), i(1, "function_name"), t({ "(" }), i(2, "args"), t({ ") = {" }),
          t({ "", "  " }), i(3, "// function body"),
          t({ "", "}" }),
        }),

        -- Show rule
        s("show", {
          t({ "#show " }), i(1, "selector"), t({ ": " }), i(2, "transformation"),
        }),

        -- Set rule
        s("set", {
          t({ "#set " }), i(1, "element"), t({ "(" }), i(2, "parameters"), t({ ")" }),
        }),
      })
    end,
  },

  -- Additional Typst-specific keybindings
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      -- Set up typst keymaps in autocmd for filetype-specific bindings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "typst",
        callback = function()
          local wk = require("which-key")
          wk.add({
            { "<leader>tp", group = "typst", buffer = true },
            { "<leader>tpc", "<cmd>!typst compile %<cr>", desc = "Compile Typst document", buffer = true },
            { "<leader>tpw", "<cmd>!typst watch %<cr>", desc = "Watch Typst document", buffer = true },
            { "<leader>tpo", function()
              local file = vim.fn.expand("%:r") .. ".pdf"
              if vim.fn.has("mac") == 1 then
                vim.cmd("!open " .. file)
              elseif vim.fn.has("unix") == 1 then
                vim.cmd("!xdg-open " .. file)
              else
                vim.cmd("!start " .. file)
              end
            end, desc = "Open compiled PDF", buffer = true },
          })
        end,
      })
      return opts
    end,
  },
}