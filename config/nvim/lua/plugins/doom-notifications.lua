-- Move LazyVim's notification keybinding to Doom Emacs style
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.notifier = opts.notifier or {}
    opts.notifier.enabled = true
    return opts
  end,
  keys = {
    -- Disable the default <leader>n keybinding
    { "<leader>n", false },
    -- Add Doom-style keybinding for notifications
    { "<leader>hn", function() require("snacks").notifier.show_history() end, desc = "Notification History" },
    -- Alternative under toggle menu
    { "<leader>tn", function() require("snacks").notifier.show_history() end, desc = "Toggle Notifications" },
  },
}