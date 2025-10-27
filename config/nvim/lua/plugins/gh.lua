-- GitHub integration using gh.nvim for PR review workflow
-- Complements octo.nvim: gh.nvim provides panel-based UI (VSCode-like),
-- while octo.nvim provides buffer-based interface

---@type LazySpec
return {
  -- litee.nvim - Required framework for gh.nvim
  {
    "ldelossa/litee.nvim",
    event = "VeryLazy", -- Load with gh.nvim
    config = function()
      require("litee.lib").setup({
        tree = {
          icon_set = "codicons",
        },
        panel = {
          orientation = "right",
          panel_size = 50,
        },
      })
    end,
  },

  -- gh.nvim - GitHub integration with panel-based PR review
  {
    "ldelossa/gh.nvim",
    dependencies = {
      "ldelossa/litee.nvim",
    },
    event = "VeryLazy", -- Load shortly after startup to ensure commands exist
    config = function()
      require("litee.gh").setup({
        -- Disable keymaps to define our own
        keymaps = {
          -- Set to false to disable default keymaps
          -- We'll define custom ones below
        },
      })
    end,
    keys = {
      -- === GitHub Panel Operations (gh.nvim) ===
      -- Panel-based UI for deep PR reviews (complements octo.nvim buffer-based UI)
      -- Using <Leader>gH (capital H) to avoid conflicts with octo.nvim

      { "<leader>gH", group = "GitHub Panels" },

      -- PR Panel & Navigation
      { "<leader>gHo", "<cmd>GHOpenPR<cr>", desc = "Open PR panel" },
      { "<leader>gHr", "<cmd>GHRefreshPR<cr>", desc = "Refresh PR" },
      { "<leader>gHt", "<cmd>GHToggleThreads<cr>", desc = "Toggle threads" },
      { "<leader>gHP", "<cmd>GHTogglePR<cr>", desc = "Toggle PR panel" },

      -- Commit Navigation (in panel)
      { "<leader>gHc", "<cmd>GHCloseCommit<cr>", desc = "Close commit" },
      { "<leader>gHe", "<cmd>GHExpandCommit<cr>", desc = "Expand commit" },
      { "<leader>gHC", "<cmd>GHCollapseCommit<cr>", desc = "Collapse commit" },
      { "<leader>gHp", "<cmd>GHPopOutCommit<cr>", desc = "Pop out commit" },

      -- Review (in panel)
      { "<leader>gHs", "<cmd>GHStartReview<cr>", desc = "Start review" },
      { "<leader>gHS", "<cmd>GHSubmitReview<cr>", desc = "Submit review" },
    },
    cmd = {
      "GHCloseCommit",
      "GHCollapseCommit",
      "GHExpandCommit",
      "GHOpenToCommit",
      "GHPopOutCommit",
      "GHToggleThreads",
      "GHOpenPR",
      "GHRefreshPR",
      "GHStartReview",
      "GHSubmitReview",
      "GHTogglePR",
    },
  },

  -- litee-gh.nvim - Additional GitHub features for litee
  {
    "ldelossa/litee-gh.nvim",
    dependencies = {
      "ldelossa/litee.nvim",
    },
    event = "VeryLazy", -- Load with gh.nvim
    config = function()
      require("litee.gh").setup()
    end,
  },
}
