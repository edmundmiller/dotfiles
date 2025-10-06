-- Git worktree management with telescope integration
return {
  -- Git worktree operations
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("git-worktree").setup({
        -- Automatically change to the root of the git repo when switching worktrees
        change_directory_command = "cd",
        -- Update current buffer when switching worktrees (useful to avoid editing wrong branch)
        update_on_change = true,
        -- Update all buffers when switching worktrees
        update_on_change_command = "e .",
        -- Clear jumps when switching worktrees
        clearjumps_on_change = true,
        -- Automatically push new branch when creating worktree
        autopush = false,
      })

      -- Load telescope extension after telescope is available
      local telescope_ok, telescope = pcall(require, "telescope")
      if telescope_ok then
        telescope.load_extension("git_worktree")
      end

      -- Hooks for worktree operations
      local Worktree = require("git-worktree")

      -- Operation hooks (optional - customize as needed)
      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          vim.notify("Switched to worktree: " .. metadata.path, vim.log.levels.INFO)
        elseif op == Worktree.Operations.Create then
          vim.notify("Created worktree: " .. metadata.path, vim.log.levels.INFO)
        elseif op == Worktree.Operations.Delete then
          vim.notify("Deleted worktree", vim.log.levels.INFO)
        end
      end)
    end,
    event = "VeryLazy",
    keys = {
      { "<leader>gw", desc = "Git Worktree" },
      { "<leader>gww", function()
        local telescope_ok = pcall(require, "telescope")
        if telescope_ok then
          require("telescope").extensions.git_worktree.git_worktrees()
        else
          vim.notify("Telescope not available", vim.log.levels.WARN)
        end
      end, desc = "Switch worktree" },
      { "<leader>gwc", function()
        local telescope_ok = pcall(require, "telescope")
        if telescope_ok then
          require("telescope").extensions.git_worktree.create_git_worktree()
        else
          vim.notify("Telescope not available", vim.log.levels.WARN)
        end
      end, desc = "Create worktree" },
      { "<leader>gwl", function()
        local telescope_ok = pcall(require, "telescope")
        if telescope_ok then
          require("telescope").extensions.git_worktree.git_worktrees()
        else
          vim.notify("Telescope not available", vim.log.levels.WARN)
        end
      end, desc = "List worktrees" },
      { "<leader>gwd", function()
        -- Simple worktree deletion without external dependencies
        local worktree_path = vim.fn.input("Worktree to delete: ")
        if worktree_path ~= "" then
          vim.cmd("!git worktree remove " .. worktree_path)
          vim.notify("Deleted worktree: " .. worktree_path, vim.log.levels.INFO)
        end
      end, desc = "Delete worktree" },
    },
  },
}