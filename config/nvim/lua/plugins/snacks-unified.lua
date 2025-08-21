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
    
    -- Dashboard configuration with GitHub integration (from snacks.nvim documentation)
    opts.dashboard = {
      width = 60,
      pane_gap = 4,
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        {
          pane = 2,
          icon = " ",
          desc = "Browse Repo",
          padding = 1,
          key = "b",
          action = function()
            Snacks.gitbrowse()
          end,
        },
        function()
          local in_git = Snacks.git.get_root() ~= nil
          local cmds = {
            {
              title = "My GitHub",
              cmd = "echo 'Assigned PRs:' && gh pr list --assignee @me -L 3 && echo '' && echo 'Assigned Issues:' && gh issue list --assignee @me -L 3",
              action = function()
                vim.ui.open("https://github.com/notifications")
              end,
              key = "n",
              icon = " ",
              height = 8,
              enabled = true,
            },
            {
              icon = " ",
              title = "Git Changes",
              cmd = "git --no-pager diff --stat -B -M -C || echo 'No changes'",
              action = function()
                if pcall(vim.cmd, "DiffviewOpen") then
                  -- DiffviewOpen succeeded
                else
                  -- Fallback to built-in diff
                  vim.cmd("vertical Git")
                end
              end,
              key = "d",
              height = 6,
            },
          }
          return vim.tbl_map(function(cmd)
            return vim.tbl_extend("force", {
              pane = 2,
              section = "terminal",
              enabled = in_git,
              padding = 1,
              ttl = 5 * 60,
              indent = 3,
            }, cmd)
          end, cmds)
        end,
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