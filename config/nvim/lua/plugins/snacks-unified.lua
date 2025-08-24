-- Unified snacks.nvim configuration
-- Consolidates all snacks settings to avoid conflicts
return {
  "folke/snacks.nvim",
  priority = 1000, -- High priority to override defaults
  opts = function(_, opts)
    -- Zen mode configuration (from doom-enhancements.lua)
    local function ghostty_font_change(increment)
      if not vim.env.GHOSTTY_RESOURCES_DIR then
        return
      end
      
      local stdout = vim.loop.new_tty(1, false)
      if stdout then
        -- Send OSC sequence for Ghostty font changes
        stdout:write(string.format("\x1b]1337;ZenMode=%s;FontChange=%d\x07", 
          increment > 0 and "on" or "off", math.abs(increment)))
        stdout:write(string.format("\x1b]777;notify;Zen Mode;Font size %s\x07",
          increment > 0 and "increased" or "restored"))
      end
    end

    opts.zen = {
      toggles = {
        dim = true,
        git_signs = false,
        mini_diff_signs = false,
      },
      show = {
        statusline = false,
        tabline = false,
      },
      win = {
        width = 120,
        height = 0,
      },
      on_open = function()
        -- Increase font size for GUI Neovim
        if vim.g.neovide then
          vim.g.neovide_scale_factor = (vim.g.neovide_scale_factor or 1.0) * 1.25
        end
        -- Increase font size using Neovim's guifont option (with error handling)
        pcall(function()
          local current_font = vim.opt.guifont:get()
          if current_font and type(current_font) == "string" and current_font ~= "" then
            local font_name, size = current_font:match("([^:]+):h(%d+)")
            if font_name and size then
              vim.opt.guifont = font_name .. ":h" .. (tonumber(size) + 4)
            end
          end
        end)
        -- Ghostty font increase
        ghostty_font_change(4)
      end,
      on_close = function()
        -- Restore font size for GUI Neovim
        if vim.g.neovide then
          vim.g.neovide_scale_factor = (vim.g.neovide_scale_factor or 1.0) / 1.25
        end
        -- Restore original font size (with error handling)
        pcall(function()
          local current_font = vim.opt.guifont:get()
          if current_font and type(current_font) == "string" and current_font ~= "" then
            local font_name, size = current_font:match("([^:]+):h(%d+)")
            if font_name and size then
              vim.opt.guifont = font_name .. ":h" .. (tonumber(size) - 4)
            end
          end
        end)
        -- Ghostty font restore
        ghostty_font_change(-4)
      end,
    }
    
    -- Notifications configuration (from doom-notifications.lua)
    opts.notifier = {
      enabled = true,
    }
    
    -- Simplified dashboard configuration
    opts.dashboard = {
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent()" },
          { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.picker.files({cwd = vim.fn.stdpath('config')})" },
          { icon = " ", key = "s", desc = "Restore Session", action = [[<cmd>lua require("persistence").load()<cr>]] },
          { icon = " ", key = "d", desc = "Open Diffview", action = function() vim.cmd("DiffviewOpen") end },
          { icon = " ", key = "o", desc = "Open Octo", action = function() vim.cmd("Octo issue list") end },
          { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "recent_files", limit = 5, padding = 1 },
        { section = "startup" },
      },
    }
    
    -- Smooth scrolling configuration
    opts.scroll = {
      animate = {
        duration = { step = 15, total = 250 },
        easing = "linear",
      },
      -- Filter to disable for terminal buffers
      filter = function(buf)
        return vim.bo[buf].buftype ~= "terminal"
      end,
    }
    
    return opts
  end,
  keys = {
    -- Zen mode keybinding
    { "<leader>tz", function() Snacks.zen() end, desc = "Toggle Zen Mode" },
    -- Disable the default <leader>n keybinding for notifications
    { "<leader>n", false },
    -- Add Doom-style keybinding for notifications
    { "<leader>hn", function() require("snacks").notifier.show_history() end, desc = "Notification History" },
    -- Alternative under toggle menu
    { "<leader>tn", function() require("snacks").notifier.show_history() end, desc = "Toggle Notifications" },
  },
}