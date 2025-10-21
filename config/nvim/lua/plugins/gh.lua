-- GitHub integration using gh.nvim for PR review workflow
-- Complements octo.nvim: gh.nvim provides panel-based UI (VSCode-like),
-- while octo.nvim provides buffer-based interface

---@type LazySpec
return {
  -- litee.nvim - Required framework for gh.nvim
  {
    "ldelossa/litee.nvim",
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
      -- PR Management
      { "<leader>ghc", "<cmd>GHCloseCommit<cr>", desc = "Close commit" },
      { "<leader>ghC", "<cmd>GHCollapseCommit<cr>", desc = "Collapse commit" },
      { "<leader>ghd", "<cmd>GHExpandCommit<cr>", desc = "Expand commit" },
      { "<leader>ghe", "<cmd>GHOpenToCommit<cr>", desc = "Open to commit" },
      { "<leader>ghp", "<cmd>GHPopOutCommit<cr>", desc = "Pop out commit" },
      { "<leader>ghz", "<cmd>GHCollapseCommit<cr>", desc = "Collapse commit" },

      -- PR Review Navigation
      { "<leader>ght", "<cmd>GHToggleThreads<cr>", desc = "Toggle threads panel" },

      -- PR Operations
      { "<leader>ghpr", "<cmd>GHOpenPR<cr>", desc = "Open PR" },
      { "<leader>ghrr", "<cmd>GHRefreshPR<cr>", desc = "Refresh PR" },

      -- Comment and Review
      { "<leader>ghs", "<cmd>GHStartReview<cr>", desc = "Start review" },
      { "<leader>ghr", "<cmd>GHSubmitReview<cr>", desc = "Submit review" },

      -- Panels
      { "<leader>ghT", "<cmd>GHToggleThreads<cr>", desc = "Toggle threads" },
      { "<leader>ghP", "<cmd>GHTogglePR<cr>", desc = "Toggle PR panel" },

      -- Navigation groups
      { "<leader>gh", group = "GitHub (gh.nvim)" },
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
    config = function()
      require("litee.gh").setup()
    end,
  },
}
