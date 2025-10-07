-- Customizations for AstroCommunity plugins and additional user plugins

---@type LazySpec
return {
  -- == AstroCommunity Plugin Customizations ==

  -- Catppuccin colorscheme - Configure for light theme (latte)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "latte", -- latte, frappe, macchiato, mocha
      background = {
        light = "latte",
        dark = "latte", -- Use latte even in dark mode
      },
      transparent_background = false,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
      integrations = {
        blink_cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        telescope = {
          enabled = true,
        },
        which_key = true,
        dashboard = true,
        neogit = true,
        vim_sneak = false,
        fern = false,
        barbar = false,
        markdown = true,
        mason = true,
        neotest = true,
        noice = true,
        semantic_tokens = true,
      },
    },
  },

  -- Neotest configuration
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = function(_, opts)
      -- Configure neotest settings for better integration
      opts.discovery = vim.tbl_extend("force", opts.discovery or {}, {
        enabled = true,
        concurrent = 1, -- Can be resource intensive
      })

      opts.running = vim.tbl_extend("force", opts.running or {}, {
        concurrent = true,
      })

      opts.summary = vim.tbl_extend("force", opts.summary or {}, {
        enabled = true,
        animated = true,
        follow = true,
        expand_errors = true,
      })

      opts.output = vim.tbl_extend("force", opts.output or {}, {
        enabled = true,
        open_on_run = "short",
      })

      opts.output_panel = vim.tbl_extend("force", opts.output_panel or {}, {
        enabled = true,
        open = "botright split | resize 15",
      })

      opts.quickfix = vim.tbl_extend("force", opts.quickfix or {}, {
        enabled = true,
        open = false,
      })

      opts.status = vim.tbl_extend("force", opts.status or {}, {
        enabled = true,
        virtual_text = true,
        signs = true,
      })

      -- Add nf-test adapter for Nextflow testing
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, require("neotest-nftest"))

      return opts
    end,
    keys = {
      -- Doom Emacs-style test keybindings
      { "<leader>T", desc = "Test" },
      { "<leader>Tt", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>Tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>Ta", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Run all tests" },
      { "<leader>Ts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
      { "<leader>To", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show test output" },
      { "<leader>TO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>TS", function() require("neotest").run.stop() end, desc = "Stop test" },
      { "<leader>Tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Watch file" },

      -- Navigation
      { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
      { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Previous failed test" },
    },
  },

  -- Obsidian.nvim - Configure vault location
  {
    "obsidian.nvim",
    opts = {
      workspaces = {
        {
          name = "vault",
          path = "~/sync/vault",
        },
      },
      -- Optional: Additional Obsidian settings
      mappings = {}, -- Keep empty to use default AstroNvim mappings
      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
      },
      completion = {
        nvim_cmp = false, -- We're using blink.cmp
        min_chars = 2,
      },
    },
  },

  -- Blink.cmp - Modern completion configuration
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "super-tab",
      },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
    },
  },

  -- Neogit - Git integration
  {
    "neogit",
    opts = {
      disable_commit_confirmation = true,
      disable_builtin_notifications = false,
      integrations = {
        diffview = true, -- Enable diffview integration
      },
      -- Optional: Configure signs in gutter
      signs = {
        section = { "", "" },
        item = { "", "" },
      },
    },
  },

  -- Mini.comment - Enhanced commenting
  {
    "mini.comment",
    opts = {
      options = {
        ignore_blank_line = true,
        start_of_line = false,
        pad_comment_parts = true,
      },
    },
  },

  -- Git-blame.nvim - Show git blame info
  {
    "f-person/git-blame.nvim",
    opts = {
      enabled = true,
      message_template = " <author> • <date> • <summary>",
      date_format = "%r",
      virtual_text_column = 80,
    },
  },

  -- Diffview.nvim - Better diff viewing
  {
    "sindrets/diffview.nvim",
    opts = {
      use_icons = true,
      view = {
        merge_tool = {
          layout = "diff3_mixed",
        },
      },
    },
  },

  -- == Dashboard Customization ==

  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  -- == Example Plugin Configurations (kept for reference) ==

  -- LuaSnip configuration example
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts)
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },

  -- Autopairs configuration example
  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts)
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            :with_pair(cond.not_after_regex "%%")
            :with_pair(cond.not_before_regex("xxx", 3))
            :with_move(cond.none())
            :with_del(cond.not_after_regex "xx")
            :with_cr(cond.none()),
        },
        Rule("a", "a", "-vim")
      )
    end,
  },
}