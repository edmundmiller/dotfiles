return {
  "greggh/claude-code.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("claude-code").setup({
      -- You can customize these settings if needed
      -- terminal = {
      --   width = 0.8,
      --   height = 0.8,
      --   border = "rounded",
      -- },
      -- keymaps = {
      --   toggle = "<C-,>",
      --   continue = "<leader>cC",
      --   verbose = "<leader>cV",
      -- },
    })
  end,
  keys = {
    { "<C-,>", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
    { "<leader>cC", "<cmd>ClaudeCodeContinue<cr>", desc = "Claude Code Continue" },
    { "<leader>cR", "<cmd>ClaudeCodeResume<cr>", desc = "Claude Code Resume" },
    { "<leader>cV", "<cmd>ClaudeCodeVerbose<cr>", desc = "Claude Code Verbose" },
  },
}