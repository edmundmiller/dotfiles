-- Snacks.nvim core configuration
-- Individual features are now configured in separate files:
-- - snacks-explorer.lua: File explorer configuration
-- - snacks-zen.lua: Zen mode with Ghostty font scaling
-- - snacks-dashboard.lua: Dashboard configuration
return {
  "folke/snacks.nvim",
  priority = 1000, -- High priority to override defaults
  opts = {
    -- Core snacks modules
    notifier = {
      enabled = true,
    },
    
    -- Smooth scrolling configuration
    scroll = {
      animate = {
        duration = { step = 15, total = 250 },
        easing = "linear",
      },
      -- Filter to disable for terminal buffers
      filter = function(buf)
        return vim.bo[buf].buftype ~= "terminal"
      end,
    },
  },
  keys = {
    -- Disable the default <leader>n keybinding for notifications
    { "<leader>n", false },
    -- Add Doom-style keybinding for notifications
    { "<leader>hn", function() require("snacks").notifier.show_history() end, desc = "Notification History" },
    -- Alternative under toggle menu
    { "<leader>tn", function() require("snacks").notifier.show_history() end, desc = "Toggle Notifications" },
  },
}