-- Customizations for AstroCommunity plugins and additional user plugins

---@type LazySpec
return {
  -- == AstroCommunity Plugin Customizations ==

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