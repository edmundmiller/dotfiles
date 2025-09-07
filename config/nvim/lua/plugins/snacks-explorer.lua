-- Snacks.nvim explorer configuration
return {
  "folke/snacks.nvim",
  opts = {
    explorer = {
      -- Configure explorer behavior
      replace_netrw = true,
      close_on_select = true, -- Close explorer when selecting a file
    },
    picker = {
      sources = {
        explorer = {
          layout = {
            layout = {
              box = "horizontal",
              width = 0.8,
              min_width = 120,
              height = 0.8,
              {
                box = "vertical",
                border = "rounded",
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              { win = "preview", title = "{preview}", border = "rounded", width = 0.5 },
            },
          },
        },
      },
    },
  },
}