-- Enhanced nf-test integration with better error handling and features
return {
  -- Enhanced nf-test adapter for neotest
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/nvim-nio",
    },
    opts = function(_, opts)
      -- Add our custom nf-test adapter
      opts.adapters = opts.adapters or {}
      
      -- Load our custom nf-test adapter with enhanced configuration
      local nftest_adapter = require("neotest-nftest").setup({
        -- Configuration options for the adapter
        args = {}, -- Extra arguments to pass to nf-test
        profile = nil, -- Default nf-test profile to use
        config_file = nil, -- Custom nf-test config file path
        
        -- Enhanced options
        junit_xml = true, -- Use JUnit XML output when possible
        timeout = 300000, -- 5 minute timeout for long-running tests
        log_level = "info", -- Logging level for nf-test
      })
      
      table.insert(opts.adapters, nftest_adapter)
      
      -- Configure neotest settings optimized for nf-test
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
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          expand_all = "e",
          output = "o",
          short = "O",
          attach = "a",
          jumpto = "i",
          run = "r",
          debug = "d",
          run_marked = "R",
          debug_marked = "D",
          clear_marked = "M",
          target = "t",
          clear_target = "T",
          next_failed = "J",
          prev_failed = "K",
          help = "?",
        },
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
      
      -- Add icons for nf-test
      opts.icons = vim.tbl_extend("force", opts.icons or {}, {
        child_indent = "│",
        child_prefix = "├",
        collapsed = "─",
        expanded = "╮",
        failed = "✖",
        final_child_indent = " ",
        final_child_prefix = "╰",
        non_collapsible = "─",
        passed = "✓",
        running = "⟳",
        running_animated = { "/", "|", "\\", "-", "/", "|", "\\", "-" },
        skipped = "ﰸ",
        unknown = "?",
        watching = "👁",
      })
      
      return opts
    end,
    config = function(_, opts)
      require("neotest").setup(opts)
      
      -- Auto-commands for enhanced nf-test integration
      local nftest_group = vim.api.nvim_create_augroup("NftestIntegration", { clear = true })
      
      -- Auto-detect nf-test files and show test summary
      vim.api.nvim_create_autocmd("BufEnter", {
        group = nftest_group,
        pattern = "*.nf.test",
        callback = function()
          -- Show neotest summary for nf-test files
          vim.defer_fn(function()
            if require("neotest").summary then
              require("neotest").summary.open()
            end
          end, 100)
        end,
      })
      
      -- Auto-refresh tests when nf-test files are saved
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = nftest_group,
        pattern = { "*.nf.test", "*.nf" },
        callback = function()
          -- Refresh test discovery
          require("neotest").summary.refresh()
        end,
      })
      
      -- Set up nf-test specific buffer options
      vim.api.nvim_create_autocmd("FileType", {
        group = nftest_group,
        pattern = "nf-test",
        callback = function()
          -- Set buffer options for nf-test files
          vim.bo.commentstring = "// %s"
          vim.bo.shiftwidth = 4
          vim.bo.tabstop = 4
          vim.bo.expandtab = true
          
          -- Add nf-test specific snippets trigger
          vim.keymap.set("i", "nftest", function()
            require("luasnip").expand_or_jump()
          end, { buffer = true, desc = "Expand nf-test snippet" })
        end,
      })
    end,
    keys = {
      -- Core test operations
      { "<leader>ctt", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>ctf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
      { "<leader>cta", function() require("neotest").run.run(vim.fn.getcwd()) end, desc = "Run all tests" },
      { "<leader>ctl", function() require("neotest").run.run_last() end, desc = "Run last test" },
      { "<leader>ctL", function() require("neotest").run.run_last({ strategy = "dap" }) end, desc = "Debug last test" },
      
      -- Test UI and output
      { "<leader>cts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
      { "<leader>cto", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show test output" },
      { "<leader>ctO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>ctq", function() require("neotest").quickfix.open() end, desc = "Open quickfix" },
      
      -- Test control
      { "<leader>ctS", function() require("neotest").run.stop() end, desc = "Stop test" },
      { "<leader>ctw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Watch file" },
      { "<leader>ctW", function() require("neotest").watch.toggle(vim.fn.getcwd()) end, desc = "Watch all" },
      
      -- nf-test specific operations
      { "<leader>ctn", function() 
        local profile = vim.fn.input("nf-test profile: ", "", "file")
        if profile ~= "" then
          require("neotest").run.run({ extra_args = { "--profile", profile } })
        end
      end, desc = "Run with nf-test profile" },
      
      { "<leader>ctc", function() 
        local config = vim.fn.input("nf-test config: ", "nf-test.config", "file")
        if config ~= "" then
          require("neotest").run.run({ extra_args = { "--config", config } })
        end
      end, desc = "Run with custom config" },
      
      { "<leader>ctd", function() 
        require("neotest").run.run({ extra_args = { "--debug" } })
      end, desc = "Run with debug output" },
      
      { "<leader>ctv", function() 
        require("neotest").run.run({ extra_args = { "--verbose" } })
      end, desc = "Run with verbose output" },
      
      { "<leader>ctT", function() 
        local tag = vim.fn.input("nf-test tag: ")
        if tag ~= "" then
          require("neotest").run.run({ extra_args = { "--tag", tag } })
        end
      end, desc = "Run tests by tag" },
      
      -- Enhanced navigation
      { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
      { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Previous failed test" },
      { "]T", function() require("neotest").jump.next() end, desc = "Next test" },
      { "[T", function() require("neotest").jump.prev() end, desc = "Previous test" },
      
      -- Debugging and inspection
      { "<leader>cti", function()
        local neotest = require("neotest")
        local tree = neotest.state.positions()
        if tree then
          print("Found tests:", vim.inspect(tree))
        else
          print("No tests found in current file")
        end
      end, desc = "Inspect discovered tests" },
      
      { "<leader>ctr", function()
        -- Refresh test discovery
        require("neotest").summary.refresh()
        print("Refreshed test discovery")
      end, desc = "Refresh test discovery" },
    },
  },
  
  -- Which-key integration for test commands
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local wk = require("which-key")
      wk.add({
        { "<leader>ct", group = "code/test" },
      })
      return opts
    end,
  },
  
  -- Add nf-test file type detection
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.filetype.add({
        extension = {
          ["nf.test"] = "nf-test",
        },
        pattern = {
          [".*%.nf%.test$"] = "nf-test",
        },
      })
      return opts
    end,
  },
}