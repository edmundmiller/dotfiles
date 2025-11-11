return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = function(_, opts)
    require("claudecode").setup(opts)

    -- Set up terminal keybindings for Claude Code terminal
    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*",
      callback = function(event)
        local bufname = vim.api.nvim_buf_get_name(event.buf)
        -- Check if this is a Claude terminal
        if bufname:match("claude") then
          local buf = event.buf
          -- Quick hide terminal (navigation handled by AstroCore global mappings)
          vim.keymap.set("t", "<C-;>", "<cmd>close<cr>", { buffer = buf, desc = "Hide terminal" })
        end
      end,
    })
  end,
  opts = {
    -- Use your installed Claude CLI
    terminal_cmd = "/Users/emiller/.local/bin/claude",

    -- Auto-start server
    auto_start = true,
    log_level = "info",

    -- Terminal configuration (right split, 30% width)
    terminal = {
      split_side = "right",
      split_width_percentage = 0.30,
      provider = "auto", -- Uses snacks.nvim
      auto_close = true,

      -- Git root detection
      cwd_provider = function(ctx)
        return require("claudecode.cwd").git_root(ctx.file_dir or ctx.cwd)
               or ctx.file_dir
               or ctx.cwd
      end,
    },

    -- Selection tracking
    track_selection = true,
    visual_demotion_delay_ms = 50,

    -- Diff options
    diff_opts = {
      auto_close_on_accept = true,
      vertical_split = true,
      open_in_current_tab = true,
      keep_terminal_focus = false, -- Jump to diff when opened
    },
  },

  keys = {
    -- Quick toggle (global)
    { "<M-c>", "<cmd>ClaudeCodeFocus<cr>", mode = { "n", "t" }, desc = "Quick toggle Claude Code" },

    -- Main commands
    { "<leader>aa", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude Code" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add buffer to context" },

    -- Visual mode
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },

    -- Diff handling
    { "<leader>aA", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Claude diff" },
  },
}
