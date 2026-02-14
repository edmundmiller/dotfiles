-- FFF.nvim - Fast fuzzy file finder
-- https://github.com/dmtrKovalenko/fff.nvim
-- Rust-backed fuzzy file picker with git status, frecency, typo-resistant search
-- Keybindings: <Leader><Leader>, <Leader>ff (astrocore.lua)

---@type LazySpec
return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {},
}
