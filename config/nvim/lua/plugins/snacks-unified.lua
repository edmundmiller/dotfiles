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
    
    -- Dashboard configuration with GitHub integration
    opts.dashboard = {
      width = 120,  -- Increase overall width for better readability
      pane_gap = 8, -- Increase gap between panes to make GitHub section wider
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        {
          pane = 2,
          icon = " ",
          title = "Browse Repo",
          section = "text",
          text = "Press 'b' to browse repository",
          padding = 1,
          key = "b",
          action = function()
            Snacks.gitbrowse()
          end,
        },
        {
          pane = 2,
          icon = " ",
          title = "GitHub Status",
          section = "terminal",
          cmd = "gh status",
          height = 12,
          padding = 1,
          ttl = 5 * 60,
          indent = 2,
          key = "n",
          action = function()
            vim.ui.open("https://github.com/notifications")
          end,
        },
        {
          pane = 2,
          icon = " ",
          title = "Open Issues",
          section = "terminal",
          cmd = "gh issue list -L 5 || echo 'No open issues'",
          height = 6,
          padding = 1,
          ttl = 5 * 60,
          indent = 2,
          key = "i",
          action = function()
            vim.fn.jobstart("gh issue list --web", { detach = true })
          end,
        },
        {
          pane = 2,
          icon = " ",
          title = "Open PRs", 
          section = "terminal",
          cmd = "gh pr list -L 5 || echo 'No open PRs'",
          height = 6,
          padding = 1,
          ttl = 5 * 60,
          indent = 2,
          key = "P",
          action = function()
            vim.fn.jobstart("gh pr list --web", { detach = true })
          end,
        },
        {
          pane = 2,
          icon = " ",
          title = "Git Status",
          section = "terminal",
          cmd = "git --no-pager diff --stat -B -M -C || echo 'No changes'",
          height = 8,
          padding = 1,
          ttl = 5 * 60,
          indent = 2,
          enabled = function()
            return Snacks.git.get_root() ~= nil
          end,
        },
        { section = "startup" },
      },
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