-- Melange colorscheme - warm, low-contrast theme for comfortable reading
return {
  {
    "savq/melange-nvim",
    enabled = true,  -- Disabled for now
  },
  
  -- Re-enable Catppuccin
  {
    "catppuccin/nvim",
    enabled = false,
  },
  
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "melange",
    },
  },
}
