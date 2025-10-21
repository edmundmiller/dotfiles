-- Nextflow Runner Plugin
-- Custom buffer UI for running Nextflow workflows with live progress tracking

return {
  -- This is a local plugin, not from a repository
  dir = vim.fn.stdpath("config") .. "/lua/nextflow-runner",
  name = "nextflow-runner",
  lazy = true,
  ft = "nextflow", -- Load only for Nextflow files

  -- Plugin configuration
  config = function()
    require("nextflow-runner").setup({
      auto_scroll = true,        -- Auto-scroll to bottom of output
      refresh_rate = 500,        -- UI refresh rate in milliseconds
      default_args = {},         -- Default arguments for nextflow run
      log_level = "info",        -- Log level: "silent", "info", "debug"
      auto_show = true,          -- Automatically show UI when running workflow
    })
  end,

  -- Keybindings
  keys = {
    -- Run workflow commands (integrate with existing <leader>nr prefix)
    {
      "<leader>nrw",
      function()
        require("nextflow-runner").run()
      end,
      desc = "Run workflow (custom UI)",
      ft = "nextflow",
    },
    {
      "<leader>nrW",
      function()
        require("nextflow-runner").run({ resume = true })
      end,
      desc = "Run workflow with resume",
      ft = "nextflow",
    },
    {
      "<leader>nrs",
      function()
        require("nextflow-runner").show()
      end,
      desc = "Show runner UI",
      ft = "nextflow",
    },
    {
      "<leader>nrx",
      function()
        require("nextflow-runner").stop()
      end,
      desc = "Stop workflow",
      ft = "nextflow",
    },
    {
      "<leader>nrh",
      function()
        require("nextflow-runner").hide()
      end,
      desc = "Hide runner UI",
      ft = "nextflow",
    },
    {
      "<leader>nrR",
      function()
        require("nextflow-runner").resume()
      end,
      desc = "Resume last workflow",
      ft = "nextflow",
    },
    {
      "<leader>nrL",
      function()
        require("nextflow-runner").show_logs()
      end,
      desc = "Show full workflow logs",
      ft = "nextflow",
    },
    {
      "<leader>nrd",
      function()
        require("nextflow-runner").show_dag()
      end,
      desc = "Show DAG (future)",
      ft = "nextflow",
    },
  },

  -- Register commands
  cmd = {
    "NextflowRun",
    "NextflowResume",
    "NextflowStop",
    "NextflowShow",
    "NextflowLogs",
  },

  init = function()
    -- Define commands
    vim.api.nvim_create_user_command("NextflowRun", function(opts)
      local args = opts.args ~= "" and opts.args or nil
      require("nextflow-runner").run({ args = args })
    end, {
      nargs = "*",
      desc = "Run Nextflow workflow with custom UI",
    })

    vim.api.nvim_create_user_command("NextflowResume", function(opts)
      local args = opts.args ~= "" and opts.args or nil
      require("nextflow-runner").run({ resume = true, args = args })
    end, {
      nargs = "*",
      desc = "Resume Nextflow workflow",
    })

    vim.api.nvim_create_user_command("NextflowStop", function()
      require("nextflow-runner").stop()
    end, {
      desc = "Stop running workflow",
    })

    vim.api.nvim_create_user_command("NextflowShow", function()
      require("nextflow-runner").show()
    end, {
      desc = "Show Nextflow runner UI",
    })

    vim.api.nvim_create_user_command("NextflowLogs", function()
      require("nextflow-runner").show_logs()
    end, {
      desc = "Show full Nextflow logs",
    })

    -- Auto-command to register which-key mappings
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "nextflow",
      callback = function()
        local wk_ok, wk = pcall(require, "which-key")
        if wk_ok then
          wk.add({
            { "<leader>nrw", desc = "Run workflow (UI)", buffer = true },
            { "<leader>nrW", desc = "Run with resume (UI)", buffer = true },
            { "<leader>nrs", desc = "Show runner UI", buffer = true },
            { "<leader>nrx", desc = "Stop workflow", buffer = true },
            { "<leader>nrh", desc = "Hide runner UI", buffer = true },
            { "<leader>nrR", desc = "Resume last workflow", buffer = true },
            { "<leader>nrL", desc = "Show full logs", buffer = true },
            { "<leader>nrd", desc = "Show DAG (future)", buffer = true },
          })
        end
      end,
    })
  end,
}
