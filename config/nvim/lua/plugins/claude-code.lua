return {
  "greggh/claude-code.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  event = "VeryLazy",
  config = function()
    require("claude-code").setup({
      -- Window configuration
      window = {
        split_ratio = 0.4,  -- Use 40% of screen for Claude
        position = "botright",  -- Open at bottom right
        enter_insert = true,  -- Automatically enter insert mode
        float = {
          width = "90%",  -- Floating window width
          height = "85%",  -- Floating window height
          border = "rounded",
        },
      },
      -- Auto-refresh configuration for file changes
      refresh = {
        enable = true,  -- Enable auto-refresh of buffers
        updatetime = 100,  -- Faster response time
        timer_interval = 1000,  -- Check for changes every second
      },
      -- Command configuration
      command = "claude",  -- CLI command to use
      keymaps = {
        toggle = {
          normal = "<C-,>",
          terminal = "<C-,>",
        },
      },
    })
    
    -- Set up which-key group for Claude
    local wk = require("which-key")
    wk.add({
      { "<leader>a", group = "ai/claude" },
    })
  end,
  keys = {
    -- Primary toggle
    { "<C-,>", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code", mode = { "n", "t" } },
    
    -- AI menu (Doom-style)
    { "<leader>aa", "<cmd>ClaudeCode<cr>", desc = "Open Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCodeContinue<cr>", desc = "Continue conversation" },
    { "<leader>ar", "<cmd>ClaudeCodeResume<cr>", desc = "Resume last session" },
    { "<leader>av", "<cmd>ClaudeCodeVerbose<cr>", desc = "Verbose mode" },
    { "<leader>af", "<cmd>ClaudeCodeFloat<cr>", desc = "Open in floating window" },
    { "<leader>as", "<cmd>ClaudeCodeSplit<cr>", desc = "Open in split" },
    
    -- Quick actions
    { "<leader>ah", function() vim.cmd("ClaudeCode --help") end, desc = "Claude help" },
    { "<leader>ad", function() vim.cmd("ClaudeCode --diff") end, desc = "Show diff" },
    { "<leader>al", function() vim.cmd("ClaudeCode --list") end, desc = "List conversations" },
    
    -- Visual mode - send selection
    { "<leader>aa", "<cmd>'<,'>ClaudeCode<cr>", desc = "Send selection to Claude", mode = "v" },
  },
  cmd = {
    "ClaudeCode",
    "ClaudeCodeContinue",
    "ClaudeCodeResume",
    "ClaudeCodeVerbose",
    "ClaudeCodeFloat",
    "ClaudeCodeSplit",
  },
}