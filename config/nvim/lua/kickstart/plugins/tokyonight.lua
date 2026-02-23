return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
        -- Override render-markdown heading groups: 20% blend (vs default 10%)
        -- gives the sleek full-line colored heading bars from the linkarzu style
        on_highlights = function(hl, c)
          local blend = function(color, amount)
            -- linear interpolation: bg + amount*(color - bg)
            local function lerp(a, b, t)
              return math.floor(a + t * (b - a) + 0.5)
            end
            local bg = { 0x1a, 0x1b, 0x26 }
            local r = tonumber(color:sub(2, 3), 16)
            local g = tonumber(color:sub(4, 5), 16)
            local b = tonumber(color:sub(6, 7), 16)
            return string.format('#%02x%02x%02x', lerp(bg[1], r, amount), lerp(bg[2], g, amount), lerp(bg[3], b, amount))
          end
          local palette = {
            c.blue,    -- H1
            c.cyan,    -- H2
            c.magenta, -- H3
            c.orange,  -- H4
            c.green,   -- H5
            c.teal,    -- H6
          }
          for i, color in ipairs(palette) do
            hl['RenderMarkdownH' .. i .. 'Bg'] = { bg = blend(color, 0.20), fg = color, bold = true }
            hl['RenderMarkdownH' .. i .. 'Fg'] = { fg = color, bold = true }
          end
        end,
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
