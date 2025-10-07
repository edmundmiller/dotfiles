-- Jujutsu (jj) version control integration
return {
  -- Core jj integration with terminal-based commands and pickers
  {
    "NicolasGB/jj.nvim",
    dependencies = {
      "folke/snacks.nvim", -- For picker integration
    },
    config = function()
      require("jj").setup({
        -- Use buffer mode for describe operations (alternative: "input")
        describe_mode = "buffer",

        -- Customize picker options (using Snacks.nvim)
        picker = {
          -- Snacks picker configuration
          layout = {
            preset = "select",
          },
        },

        -- Syntax highlighting customization (optional)
        -- colors = {
        --   added = "#a6e3a1",
        --   removed = "#f38ba8",
        --   changed = "#89b4fa",
        -- },
      })
    end,
    cmd = {
      "J",           -- Run jj commands
      "JjStatus",    -- Show status
      "JjLog",       -- Show log
      "JjDescribe",  -- Describe change
      "JjNew",       -- Create new change
      "JjEdit",      -- Edit change
      "JjDiff",      -- Show diff
    },
    keys = {
      { "<leader>j", desc = "Jujutsu (jj)" },
      { "<leader>js", "<cmd>JjStatus<cr>", desc = "JJ status picker" },
      { "<leader>jl", "<cmd>JjLog<cr>", desc = "JJ log viewer" },
      { "<leader>jd", "<cmd>JjDiff<cr>", desc = "JJ diff viewer" },
      { "<leader>jD", "<cmd>JjDescribe<cr>", desc = "JJ describe (edit message)" },
      { "<leader>jc", "<cmd>JjNew<cr>", desc = "JJ create new change" },
      { "<leader>je", "<cmd>JjEdit<cr>", desc = "JJ edit change" },
      { "<leader>j:", "<cmd>J ", desc = "JJ command" },
    },
  },

  -- Gutter signs for jj diffs (like gitsigns for git)
  {
    "evanphx/jjsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("jjsigns").setup({
        -- Enable signs in gutter
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },

        -- Highlighting options
        signcolumn = true,  -- Toggle with signcolumn
        numhl = false,      -- Toggle num column highlights
        linehl = false,     -- Toggle line highlights
        word_diff = false,  -- Toggle word diff

        -- Base revision for diff (default: @)
        base_revision = "@-",

        -- Performance tuning
        update_debounce = 100,  -- Debounce updates (ms)

        -- Auto-attach to jj repo files
        attach_to_untracked = true,
      })
    end,
    keys = {
      { "<leader>jS", "<cmd>JjSigns toggle<cr>", desc = "Toggle jjsigns" },
    },
  },

  -- LazyJJ - LazyGit-style TUI for jj
  {
    "swaits/lazyjj.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("lazyjj").setup({
        -- Custom keybinding (default: <leader>jj)
        mapping = "<leader>jj",
      })
    end,
    cmd = "LazyJJ",
    keys = {
      { "<leader>jj", "<cmd>LazyJJ<cr>", desc = "Toggle LazyJJ UI" },
    },
  },

  -- Conflict resolution tool for jj
  {
    "rafikdraoui/jj-diffconflicts",
    cmd = "JJDiffConflicts",
    keys = {
      { "<leader>jC", "<cmd>JJDiffConflicts<cr>", desc = "JJ resolve conflicts" },
    },
    config = function()
      -- Plugin auto-configures when invoked
      -- Additional configuration can be added here if needed
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "*",
        callback = function()
          -- Auto-detect conflict markers and suggest resolution
          local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          for _, line in ipairs(lines) do
            if line:match("^<<<<<<<") or line:match("^>>>>>>>") or line:match("^=======") then
              vim.notify(
                "Conflict markers detected. Use :JJDiffConflicts to resolve",
                vim.log.levels.INFO,
                { title = "JJ Conflicts" }
              )
              break
            end
          end
        end,
      })
    end,
  },
}
