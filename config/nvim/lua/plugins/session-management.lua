-- Enhanced session management for project-specific workflows
return {
  -- Enhanced persistence configuration
  {
    "folke/persistence.nvim",
    opts = {
      dir = vim.fn.stdpath("state") .. "/sessions/",
      options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" },
      pre_save = function()
        -- Close unwanted buffers before saving session
        vim.api.nvim_exec_autocmds("User", { pattern = "SessionSavePre" })
      end,
      save_empty = false,
    },
    config = function(_, opts)
      require("persistence").setup(opts)
      
      -- Auto-save session when leaving Neovim
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          -- Only save if we have a valid session (not just a single file)
          if vim.fn.argc() == 0 and #vim.api.nvim_list_bufs() > 1 then
            require("persistence").save()
          end
        end,
      })
      
      -- Clean up session before saving
      vim.api.nvim_create_autocmd("User", {
        pattern = "SessionSavePre",
        callback = function()
          -- Close terminal buffers
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
          
          -- Close help buffers
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "help" then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
          
          -- Close unnamed buffers
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
        end,
      })
    end,
  },

  -- Auto session management
  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup({
        log_level = vim.log.levels.ERROR,
        auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
        auto_session_use_git_branch = true,
        auto_session_root_dir = vim.fn.stdpath("data") .. "/sessions/",
        auto_session_enabled = true,
        auto_save_enabled = true,
        auto_restore_enabled = false, -- Let persistence handle this
        auto_session_create_enabled = false,
        
        -- Session lens configuration
        session_lens = {
          buftypes_to_ignore = {},
          load_on_setup = true,
          theme_conf = { border = true },
          previewer = false,
        },
        
        pre_save_cmds = {
          "tabdo NeoTreeClose",      -- Close neo-tree in all tabs
          "tabdo DBUIClose",         -- Close database UI
          "silent! %bd|e#|bd#",      -- Close all buffers except current
        },
        
        post_restore_cmds = {
          "silent! doautocmd BufRead", -- Trigger file type detection
        },
      })
    end,
  },

  -- Session manager with telescope integration
  {
    "Shatur/neovim-session-manager",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      local Path = require("plenary.path")
      local config = require("session_manager.config")
      
      require("session_manager").setup({
        sessions_dir = Path:new(vim.fn.stdpath("data"), "sessions"),
        autoload_mode = config.AutoloadMode.Disabled,
        autosave_last_session = true,
        autosave_ignore_not_normal = true,
        autosave_ignore_dirs = {},
        autosave_ignore_filetypes = {
          "gitcommit",
          "gitrebase",
        },
        autosave_ignore_buftypes = {},
        autosave_only_in_session = false,
        max_path_length = 80,
      })
      
      -- Auto commands for session management
      local config_group = vim.api.nvim_create_augroup("MySessionManager", {})
      
      vim.api.nvim_create_autocmd({ "BufWritePre" }, {
        group = config_group,
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            -- Don't save 'nofile' and 'help' buffers
            if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
              vim.schedule(function()
                pcall(vim.api.nvim_buf_delete, buf, {})
              end)
            end
          end
        end,
      })
    end,
  },

  -- Project-specific session utilities
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local wk = require("which-key")
      wk.add({
        -- Session management keybindings
        { "<leader>q", group = "quit/session" },
        { "<leader>qs", "<cmd>lua require('persistence').save()<cr>", desc = "Save session" },
        { "<leader>ql", "<cmd>lua require('persistence').load()<cr>", desc = "Load session" },
        { "<leader>qL", "<cmd>lua require('persistence').load({ last = true })<cr>", desc = "Load last session" },
        { "<leader>qd", "<cmd>lua require('persistence').stop()<cr>", desc = "Don't save session" },
        
        -- Auto session keybindings
        { "<leader>qS", "<cmd>SessionSave<cr>", desc = "Save current session" },
        { "<leader>qR", "<cmd>SessionRestore<cr>", desc = "Restore session" },
        { "<leader>qX", "<cmd>SessionDelete<cr>", desc = "Delete session" },
      })
      
      return opts
    end,
  },

}
