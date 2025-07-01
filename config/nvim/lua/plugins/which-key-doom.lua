return {
  "folke/which-key.nvim",
  opts = function(_, opts)
    -- Extend the default which-key configuration with Doom Emacs-style groups
    local wk = require("which-key")
    
    -- Add Doom Emacs-style group descriptions
    wk.add({
      { "<leader>f", group = "file" },
      { "<leader>b", group = "buffer" },
      { "<leader>w", group = "window" },
      { "<leader>s", group = "search" },
      { "<leader>p", group = "project" },
      { "<leader>g", group = "git" },
      { "<leader>c", group = "code" },
      { "<leader>t", group = "toggle" },
      { "<leader>h", group = "help" },
      { "<leader>q", group = "quit/session" },
      { "<leader>o", group = "obsidian/notes" },
      { "<leader>n", group = "notes" },
      { "<leader>i", group = "insert" },
      { "<leader>e", group = "error" },
      { "<leader>x", group = "diagnostics/quickfix" },
      { "<leader>m", group = "local leader" },
      { "<leader>l", group = "lsp" },
      { "<leader>d", group = "debug" },
      { "<leader>r", group = "refactor" },
      { "<leader>v", group = "version control" },
      { "<leader>T", group = "treesitter" },
      { "<leader>u", group = "ui" },
    })

    -- Configure which-key to be more like Doom Emacs
    opts.preset = "modern"
    opts.delay = 300  -- Faster popup like Doom
    opts.win = {
      border = "rounded",
      padding = { 1, 2 }, -- extra window padding [top/bottom, right/left]
      title = true,
      title_pos = "center",
      zindex = 1000,
    }
    
    return opts
  end,
}