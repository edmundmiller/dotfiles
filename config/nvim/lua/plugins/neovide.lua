-- Neovide GUI configuration
-- Only loads when running in Neovide
if not vim.g.neovide then return {} end

return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    options = {
      opt = {
        -- Font configuration (adjust to your preference)
        guifont = "JetBrainsMono Nerd Font:h14",
        linespace = 0,
      },
      g = {
        -- Neovide specific settings
        neovide_scale_factor = 1.0,
        neovide_padding_top = 0,
        neovide_padding_bottom = 0,
        neovide_padding_right = 0,
        neovide_padding_left = 0,

        -- Optional: Additional Neovide settings
        neovide_transparency = 0.95,
        neovide_floating_blur_amount_x = 2.0,
        neovide_floating_blur_amount_y = 2.0,
        neovide_scroll_animation_length = 0.3,
        neovide_hide_mouse_when_typing = true,
        neovide_refresh_rate = 60,
        neovide_refresh_rate_idle = 5,
        neovide_cursor_animation_length = 0.05,
        neovide_cursor_trail_size = 0.8,
        neovide_cursor_antialiasing = true,
        neovide_cursor_vfx_mode = "railgun", -- Options: "", "torpedo", "pixiedust", "sonicboom", "railgun", "wireframe"
      },
    },
    mappings = {
      n = {
        -- Scale factor controls
        ["<C-=>"] = {
          function()
            vim.g.neovide_scale_factor = math.min(vim.g.neovide_scale_factor * 1.1, 2.0)
          end,
          desc = "Increase Neovide scale factor",
        },
        ["<C-->"] = {
          function()
            vim.g.neovide_scale_factor = math.max(vim.g.neovide_scale_factor / 1.1, 0.5)
          end,
          desc = "Decrease Neovide scale factor",
        },
        ["<C-0>"] = {
          function()
            vim.g.neovide_scale_factor = 1.0
          end,
          desc = "Reset Neovide scale factor",
        },
      },
    },
    commands = {
      -- Convenient commands for scale management
      NeovideScaleIncrease = {
        function()
          vim.g.neovide_scale_factor = math.min(vim.g.neovide_scale_factor * 1.1, 2.0)
        end,
        desc = "Increase Neovide scale factor",
      },
      NeovideScaleDecrease = {
        function()
          vim.g.neovide_scale_factor = math.max(vim.g.neovide_scale_factor / 1.1, 0.5)
        end,
        desc = "Decrease Neovide scale factor",
      },
      NeovideScaleReset = {
        function()
          vim.g.neovide_scale_factor = 1.0
        end,
        desc = "Reset Neovide scale factor",
      },
      NeovideToggleFullscreen = {
        function()
          vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
        end,
        desc = "Toggle Neovide fullscreen",
      },
    },
  },
}