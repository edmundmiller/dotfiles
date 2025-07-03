return {
  -- Custom nf-test adapter for neotest (disabled - using enhanced version)
  {
    "nvim-neotest/neotest",
    enabled = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/nvim-nio",
    },
    opts = function(_, opts)
      -- Add our custom nf-test adapter
      opts.adapters = opts.adapters or {}
      
      -- Load our custom nf-test adapter
      local nftest_adapter = require("neotest-nftest").setup({
        -- Configuration options for the adapter
        args = {}, -- Extra arguments to pass to nf-test
        profile = nil, -- Default nf-test profile to use
        config_file = nil, -- Custom nf-test config file path
      })
      
      table.insert(opts.adapters, nftest_adapter)
      
      -- Configure neotest settings for better nf-test integration
      opts.discovery = vim.tbl_extend("force", opts.discovery or {}, {
        enabled = true,
        concurrent = 1, -- nf-test can be resource intensive
      })
      
      opts.running = vim.tbl_extend("force", opts.running or {}, {
        concurrent = true,
      })
      
      opts.summary = vim.tbl_extend("force", opts.summary or {}, {
        enabled = true,
        animated = true,
        follow = true,
        expand_errors = true,
      })
      
      opts.output = vim.tbl_extend("force", opts.output or {}, {
        enabled = true,
        open_on_run = "short",
      })
      
      opts.output_panel = vim.tbl_extend("force", opts.output_panel or {}, {
        enabled = true,
        open = "botright split | resize 15",
      })
      
      opts.quickfix = vim.tbl_extend("force", opts.quickfix or {}, {
        enabled = true,
        open = false,
      })
      
      opts.status = vim.tbl_extend("force", opts.status or {}, {
        enabled = true,
        virtual_text = true,
        signs = true,
      })
      
      return opts
    end,
    keys = {
      -- Doom Emacs-style test keybindings
      { "<leader>tt", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Run all tests" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show test output" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop test" },
      { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Watch file" },
      
      -- Additional nf-test specific bindings
      { "<leader>tn", function() 
        -- Run with specific nf-test profile
        local profile = vim.fn.input("nf-test profile: ")
        if profile ~= "" then
          require("neotest").run.run({ extra_args = { "--profile", profile } })
        end
      end, desc = "Run test with profile" },
      
      { "<leader>tc", function() 
        -- Run with config file
        local config = vim.fn.input("nf-test config file: ")
        if config ~= "" then
          require("neotest").run.run({ extra_args = { "--config", config } })
        end
      end, desc = "Run test with config" },
      
      { "<leader>td", function() 
        -- Run with debug output
        require("neotest").run.run({ extra_args = { "--debug" } })
      end, desc = "Run test with debug" },
      
      -- Navigation
      { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
      { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Previous failed test" },
    },
  },
  
  -- Enhanced which-key groups for testing
}