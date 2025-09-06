-- Doom Emacs-style motion configuration
-- Restores traditional s/S substitute behavior

return {
  -- Disable flash.nvim on s/S to restore substitute behavior
  {
    "folke/flash.nvim",
    opts = {
      -- Disable s/S mappings to restore normal substitute behavior
      modes = {
        char = {
          enabled = true,
          -- Keep f/F/t/T but disable s/S
          keys = { "f", "F", "t", "T", ";", "," },
        },
        search = {
          enabled = true,
        },
      },
    },
  },
}