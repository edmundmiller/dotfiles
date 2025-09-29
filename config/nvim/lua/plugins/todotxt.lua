-- todotxt.nvim configuration for todo.txt management
return {
  {
    "edmundmiller/todotxt.nvim",
    ft = { "todotxt" },  -- Load on todotxt filetype
    event = "VeryLazy",  -- Also load on VeryLazy to ensure it's available
    cmd = { "TodoTxt", "DoneTxt" },
    keys = {
      { "<leader>tn", "<cmd>TodoTxt new<cr>", desc = "New todo entry" },
      { "<leader>tt", "<cmd>TodoTxt<cr>", desc = "Toggle todo.txt" },
      { "<leader>td", "<cmd>DoneTxt<cr>", desc = "Toggle done.txt" },
    },
    opts = {
      todotxt = vim.fn.expand("~/Documents/Todo/todo.txt"),
      donetxt = vim.fn.expand("~/Documents/Todo/done.txt"),
      create_commands = true,
    },
    config = function(_, opts)
      require("todotxt").setup(opts)
      
      -- Additional keymappings for todotxt buffers
      -- These will only work when in a todotxt buffer
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "todotxt",
        callback = function()
          local buf_opts = { buffer = true, desc = "" }
          
          -- Task management
          vim.keymap.set("n", "<cr>", "<Plug>(TodoTxtToggleState)", 
            vim.tbl_extend("force", buf_opts, { desc = "Toggle task state" }))
          vim.keymap.set("n", "<leader>tp", "<Plug>(TodoTxtCyclePriority)", 
            vim.tbl_extend("force", buf_opts, { desc = "Cycle priority" }))
          vim.keymap.set("n", "<leader>tm", "<Plug>(TodoTxtMoveDone)", 
            vim.tbl_extend("force", buf_opts, { desc = "Move done tasks" }))
          
          -- Sorting commands
          vim.keymap.set("n", "<leader>tss", "<Plug>(TodoTxtSortTasks)", 
            vim.tbl_extend("force", buf_opts, { desc = "Sort tasks (default)" }))
          vim.keymap.set("n", "<leader>tsp", "<Plug>(TodoTxtSortByPriority)", 
            vim.tbl_extend("force", buf_opts, { desc = "Sort by priority" }))
          vim.keymap.set("n", "<leader>tsc", "<Plug>(TodoTxtSortByContext)", 
            vim.tbl_extend("force", buf_opts, { desc = "Sort by context" }))
          vim.keymap.set("n", "<leader>tsP", "<Plug>(TodoTxtSortByProject)", 
            vim.tbl_extend("force", buf_opts, { desc = "Sort by project" }))
          vim.keymap.set("n", "<leader>tsd", "<Plug>(TodoTxtSortByDueDate)", 
            vim.tbl_extend("force", buf_opts, { desc = "Sort by due date" }))
        end,
      })
    end,
  },
  
  -- Ensure treesitter has todotxt parser
  {
    "nvim-treesitter/nvim-treesitter",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = { "todotxt" },
    },
  },
}