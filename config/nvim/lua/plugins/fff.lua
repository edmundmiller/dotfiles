-- FFF.nvim - Fast fuzzy file finder
-- https://github.com/dmtrKovalenko/fff.nvim
-- Rust-backed fuzzy file picker with git status, frecency, typo-resistant search

---@type LazySpec
return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {},
  keys = {
    { "<Leader>ff", function() require("fff").find_files() end, desc = "Find files (fff)" },
    { "<Leader>fF", function() require("fff").find_in_git_root() end, desc = "Find files in git root" },
  },
}
