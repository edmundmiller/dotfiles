return {
  "obsidian-nvim/obsidian.nvim",
  -- the obsidian vault in this default config  ~/obsidian-vault
  -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand':
  -- event = { "bufreadpre " .. vim.fn.expand "~" .. "/my-vault/**.md" },
  event = { "BufReadPre  */obsidian-vault/*.md" },

  dependencies = {
    "nvim-lua/plenary.nvim",
    { "hrsh7th/nvim-cmp", optional = true },
    {
      "AstroNvim/astrocore",
      opts = {
        mappings = {
          n = {
            ["gf"] = {
              function()
                if require("obsidian").util.cursor_on_markdown_link() then
                  return "<Cmd>Obsidian follow_link<CR>"
                else
                  return "gf"
                end
              end,
              desc = "Obsidian Follow Link",
            },
            ["<leader>nd"] = {
              "<cmd>ObsidianToday<cr>",
              desc = "Open daily note",
            },
          },
        },
      },
    },
  },

  init = function()
    -- Set conceallevel for Obsidian UI features
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*/obsidian-vault/*.md",
      callback = function()
        vim.opt_local.conceallevel = 2
      end,
    })
  end,

  opts = function(_, opts)
    local astrocore = require "astrocore"
    return astrocore.extend_tbl(opts, {
      workspaces = {
        {
          path = vim.env.HOME .. "/obsidian-vault",
        },
      },

      -- Disable legacy commands (v4.0 prep)
      legacy_commands = false,

      open = {
        use_advanced_uri = true,
      },

      finder = (astrocore.is_available "snacks.pick" and "snacks.pick")
        or (astrocore.is_available "telescope.nvim" and "telescope.nvim")
        or (astrocore.is_available "fzf-lua" and "fzf-lua")
        or (astrocore.is_available "mini.pick" and "mini.pick"),

      templates = {
        subdir = "06_Metadata/Templates",
        date_format = "%Y-%m-%d-%a",
        time_format = "%H:%M",
      },

      daily_notes = {
        folder = "00_Inbox/Daily",
      },

      completion = {
        nvim_cmp = astrocore.is_available "nvim-cmp",
        blink = astrocore.is_available "blink",
      },

      ui = {
        enable = true,
      },

      checkbox = {
        order = { " ", "x" },
      },

      -- Updated frontmatter config (not deprecated)
      frontmatter = {
        func = function(note)
          -- This is equivalent to the default frontmatter function.
          local out = { id = note.id, aliases = note.aliases, tags = note.tags }
          -- `note.metadata` contains any manually added fields in the frontmatter.
          -- So here we just make sure those fields are kept in the frontmatter.
          if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
            for k, v in pairs(note.metadata) do
              out[k] = v
            end
          end
          return out
        end,
      },

      -- Optional, by default when you use `:Obsidian follow_link` on a link to an external
      -- URL it will be ignored but you can customize this behavior here.
      follow_url_func = vim.ui.open,
    })
  end,
}
