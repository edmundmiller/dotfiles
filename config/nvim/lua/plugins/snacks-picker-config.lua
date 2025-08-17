-- Configure snacks picker with Ctrl-j/k navigation
-- Note: Ctrl-j/k should work by default, but we're being explicit here
return {
  "folke/snacks.nvim",
  priority = 1000, -- Load early to ensure our config takes precedence
  opts = function(_, opts)
    -- Ensure picker config exists
    opts.picker = opts.picker or {}
    opts.picker.win = opts.picker.win or {}
    opts.picker.win.input = opts.picker.win.input or {}
    
    -- Configure the input window keys (where you type to filter)
    opts.picker.win.input.keys = vim.tbl_deep_extend("force", opts.picker.win.input.keys or {}, {
      -- Use the correct action names from snacks.nvim documentation
      ["<c-j>"] = { "list_down", mode = { "i", "n" } },
      ["<c-k>"] = { "list_up", mode = { "i", "n" } },
      ["<c-n>"] = { "list_down", mode = { "i", "n" } },
      ["<c-p>"] = { "list_up", mode = { "i", "n" } },
      ["<down>"] = { "list_down", mode = { "i", "n" } },
      ["<up>"] = { "list_up", mode = { "i", "n" } },
      -- Preview scrolling
      ["<c-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
      ["<c-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
      ["<c-f>"] = { "preview_scroll_down", mode = { "i", "n" } },
      ["<c-b>"] = { "preview_scroll_up", mode = { "i", "n" } },
    })
    
    -- Also configure the list window keys (the results list)
    opts.picker.win.list = opts.picker.win.list or {}
    opts.picker.win.list.keys = vim.tbl_deep_extend("force", opts.picker.win.list.keys or {}, {
      ["<c-j>"] = { "list_down", mode = { "n" } },
      ["<c-k>"] = { "list_up", mode = { "n" } },
      ["j"] = { "list_down", mode = { "n" } },
      ["k"] = { "list_up", mode = { "n" } },
    })
    
    return opts
  end,
}