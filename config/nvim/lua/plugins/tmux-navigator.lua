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
    { "<C-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", mode = "n", desc = "Navigate left (tmux/vim)" },
    { "<C-j>", "<cmd><C-U>TmuxNavigateDown<cr>", mode = "n", desc = "Navigate down (tmux/vim)" },
    { "<C-k>", "<cmd><C-U>TmuxNavigateUp<cr>", mode = "n", desc = "Navigate up (tmux/vim)" },
    { "<C-l>", "<cmd><C-U>TmuxNavigateRight<cr>", mode = "n", desc = "Navigate right (tmux/vim)" },
    { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>", mode = "n", desc = "Navigate previous (tmux/vim)" },
  },
}

