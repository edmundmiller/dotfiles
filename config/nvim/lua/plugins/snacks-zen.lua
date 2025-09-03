-- Snacks.nvim zen mode configuration with Ghostty font scaling
return {
  "folke/snacks.nvim",
  opts = {
    zen = {
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
    },
  },
  keys = {
    { "<leader>tz", function() Snacks.zen() end, desc = "Toggle Zen Mode" },
  },
}