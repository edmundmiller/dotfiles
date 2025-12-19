-- Prise Configuration
-- Terminal multiplexer for modern terminals
-- https://github.com/rockorager/prise

local prise = require("prise")
local ui = prise.tiling()

ui.setup({
    -- Catppuccin Mocha Theme
    -- https://github.com/catppuccin/catppuccin
    theme = {
        -- Mode indicators
        mode_normal = "#89b4fa",      -- Blue
        mode_command = "#f38ba8",     -- Red

        -- Background layers (dark to light)
        bg1 = "#1e1e2e",              -- Base (darkest)
        bg2 = "#313244",              -- Mantle
        bg3 = "#45475a",              -- Surface0
        bg4 = "#585b70",              -- Surface1

        -- Foreground colors
        fg_bright = "#cdd6f4",        -- Text
        fg_dim = "#a6adc8",           -- Subtext0
        fg_dark = "#1e1e2e",          -- Base (for light backgrounds)

        -- Accent colors
        accent = "#89b4fa",           -- Blue
        green = "#a6e3a1",            -- Green
        yellow = "#f9e2af",           -- Yellow
    },

    -- Pane borders (box mode with rounded corners)
    borders = {
        enabled = true,
        mode = "separator",           -- tmux-style borders between panes only
        style = "rounded",            -- Rounded corners
        focused_color = "#89b4fa",    -- Blue for active pane
        unfocused_color = "#585b70",  -- Gray for inactive panes
        show_single_pane = false,     -- Hide border when only one pane
    },

    -- Status bar
    status_bar = {
        enabled = true,
    },

    -- Tab bar
    tab_bar = {
        show_single_tab = false,      -- Hide tab bar with single tab
    },

    -- macOS Option key behavior
    macos_option_as_alt = "true",     -- Use Option as Alt for keybindings

    -- Default leader key is Super+k (Cmd+k on macOS)
    -- Default keybindings:
    --   v          - Split horizontal (side-by-side)
    --   s          - Split vertical (stacked)
    --   Enter      - Auto split (smart direction)
    --   h/j/k/l    - Focus left/down/up/right
    --   H/J/K/L    - Resize pane
    --   w          - Close pane
    --   z          - Toggle zoom
    --   t          - New tab
    --   c          - Close tab
    --   n/p        - Next/previous tab
    --   1-9        - Jump to tab by number
    --   r          - Rename tab
    --   d          - Detach session
    --   q          - Quit
    --
    -- Command Palette: Super+p (Cmd+p on macOS)
})

return ui
