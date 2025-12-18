-- goose.nvim - Neovim integration with Block's Goose AI agent
-- Provides persistent workspace sessions with file tracking and diff/revert capabilities

---@type LazySpec
return {
  "azorng/goose.nvim",

  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        anti_conceal = { enabled = false },
      },
    },
  },

  opts = {
    -- Disable default keymaps to avoid conflicts with Git bindings (<Leader>g*)
    default_global_keymaps = false,

    -- Use snacks picker
    prefered_picker = "snacks",

    -- UI Configuration - match claudecode/opencode style
    ui = {
      window_type = "float",
      window_width = 0.30,
      layout = "right",
      input_height = 0.15,
      fullscreen = false,
      display_model = true,
      display_goose_mode = false,
    },

    -- Provider configuration - matching opencode models
    providers = {
      anthropic = {
        "claude-sonnet-4-5",
        "claude-opus-4-5",
        "claude-haiku-4-5",
      },
    },

    -- System instructions
    system_instructions = [[
- Use jujutsu (jj) for version control, not git
- Follow the coding style in existing files
- Write comprehensive commit messages
]],

    -- Window-specific keymaps (active when in goose)
    keymap = {
      window = {
        submit = "<cr>",
        submit_insert = "<cr>",
        close = "<esc>",
        stop = "<C-c>",
        next_message = "]]",
        prev_message = "[[",
        mention_file = "@",
        toggle_pane = "<tab>",
        prev_prompt_history = "<up>",
        next_prompt_history = "<down>",
      },
    },
  },

  -- Global keybindings (all under <Leader>G to avoid Git conflicts)
  keys = {
    -- Main Commands
    { "<Leader>Gg", "<cmd>Goose<cr>", desc = "Toggle Goose" },
    { "<Leader>Gi", function() require("goose.api").open_input() end, desc = "Goose input" },
    { "<Leader>GI", function() require("goose.api").open_input_new_session() end, desc = "Goose input (new session)" },
    { "<Leader>Go", function() require("goose.api").open_output() end, desc = "Open Goose output" },
    { "<Leader>Gt", function() require("goose.api").toggle_focus() end, desc = "Toggle focus" },
    { "<Leader>Gq", function() require("goose.api").close() end, desc = "Close Goose" },
    { "<Leader>Gf", function() require("goose.api").toggle_fullscreen() end, desc = "Toggle fullscreen" },

    -- Session Management
    { "<Leader>Gs", function() require("goose.api").select_session() end, desc = "Select session" },
    { "<Leader>Gp", function() require("goose.api").configure_provider() end, desc = "Configure provider" },
    { "<Leader>G.", function() require("goose.api").open_config() end, desc = "Open Goose config" },
    { "<Leader>G?", function() require("goose.api").inspect_session() end, desc = "Inspect session" },

    -- Diff & Revert
    { "<Leader>Gd", function() require("goose.api").diff_open() end, desc = "Open diff view" },
    { "<Leader>G]", function() require("goose.api").diff_next() end, desc = "Next file diff" },
    { "<Leader>G[", function() require("goose.api").diff_prev() end, desc = "Previous file diff" },
    { "<Leader>Gc", function() require("goose.api").diff_close() end, desc = "Close diff view" },
    { "<Leader>Gra", function() require("goose.api").diff_revert_all() end, desc = "Revert all changes" },
    { "<Leader>Grt", function() require("goose.api").diff_revert_this() end, desc = "Revert current file" },

    -- Quick Toggle (matches <M-c> for Claude, <M-o> for opencode)
    { "<M-g>", "<cmd>Goose<cr>", mode = { "n", "t" }, desc = "Quick toggle Goose" },
  },
}
