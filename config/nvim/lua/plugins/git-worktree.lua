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

      -- Load telescope extension
      require("telescope").load_extension("git_worktree")

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
    keys = {
      -- Telescope worktree pickers
      {
        "<leader>gww",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Switch worktree",
      },
      {
        "<leader>gwc",
        function()
          require("telescope").extensions.git_worktree.create_git_worktree()
        end,
        desc = "Create worktree",
      },
      -- Additional convenience mappings
      {
        "<leader>gwl",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "List worktrees",
      },
      {
        "<leader>gwd",
        function()
          -- Custom function to delete worktree
          local worktree = require("git-worktree")
          local telescope = require("telescope")
          
          -- List worktrees and delete selected one
          telescope.extensions.git_worktree.git_worktrees({
            attach_mappings = function(_, map)
              map("i", "<CR>", function(prompt_bufnr)
                local selection = require("telescope.actions.state").get_selected_entry()
                require("telescope.actions").close(prompt_bufnr)
                if selection then
                  worktree.delete_worktree(selection.value)
                end
              end)
              map("n", "<CR>", function(prompt_bufnr)
                local selection = require("telescope.actions.state").get_selected_entry()
                require("telescope.actions").close(prompt_bufnr)
                if selection then
                  worktree.delete_worktree(selection.value)
                end
              end)
              return true
            end,
          })
        end,
        desc = "Delete worktree",
      },
    },
  },
}