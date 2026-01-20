---@type LazySpec
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  init = function()
    -- Avoid default mappings (which can interfere with insert-mode backspace).
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    -- NOTE: Avoid `<C-U>` here: with `<cmd>…` it can be interpreted literally as `^U`.
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", mode = "n", desc = "Navigate left (tmux/vim)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", mode = "n", desc = "Navigate down (tmux/vim)" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", mode = "n", desc = "Navigate up (tmux/vim)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", mode = "n", desc = "Navigate right (tmux/vim)" },
    { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", mode = "n", desc = "Navigate previous (tmux/vim)" },
  },
}

