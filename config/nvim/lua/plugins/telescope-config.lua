return {
  -- Configure Telescope with C-j/C-k navigation
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require("telescope.actions")
      
      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
        mappings = {
          i = {
            -- Navigation with C-j and C-k in insert mode
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            
            -- Keep other useful insert mode mappings
            ["<C-n>"] = actions.move_selection_next,
            ["<C-p>"] = actions.move_selection_previous,
            ["<Down>"] = actions.move_selection_next,
            ["<Up>"] = actions.move_selection_previous,
            
            -- Scrolling preview
            ["<C-d>"] = actions.preview_scrolling_down,
            ["<C-u>"] = actions.preview_scrolling_up,
          },
          n = {
            -- Navigation with j and k in normal mode
            ["j"] = actions.move_selection_next,
            ["k"] = actions.move_selection_previous,
            
            -- Scrolling preview
            ["<C-d>"] = actions.preview_scrolling_down,
            ["<C-u>"] = actions.preview_scrolling_up,
          },
        },
      })
      
      return opts
    end,
  },
}