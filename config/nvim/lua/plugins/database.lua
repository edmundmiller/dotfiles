-- Database integration for SQL development and data analysis
return {
  -- vim-dadbod: Database interface
  {
    "tpope/vim-dadbod",
    dependencies = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 40
      
      -- Icons configuration
      vim.g.db_ui_icons = {
        expanded = {
          db = "▾ ",
          buffers = "▾ ",
          saved_queries = "▾ ",
          schemas = "▾ ",
          schema = "▾ פּ",
          tables = "▾ 藺",
          table = "▾ ",
        },
        collapsed = {
          db = "▸ ",
          buffers = "▸ ",
          saved_queries = "▸ ",
          schemas = "▸ ",
          schema = "▸ פּ",
          tables = "▸ 藺",
          table = "▸ ",
        },
        saved_query = "",
        new_query = "璘",
        tables = "離",
        buffers = "﬘",
        add_connection = "",
        connection_ok = "✓",
        connection_error = "✕",
      }
      
      -- Auto-complete setup
      vim.g.db_ui_use_nvim_notify = 1
      
      -- Save location for queries
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      vim.g.db_ui_tmp_query_location = vim.fn.stdpath("data") .. "/db_ui/tmp"
      
      -- Execute on save
      vim.g.db_ui_execute_on_save = false
    end,
  },

  -- Database completion
  {
    "kristijanhusak/vim-dadbod-completion",
    ft = { "sql", "mysql", "plsql" },
    lazy = true,
    config = function()
      -- Setup dadbod completion for SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          -- Add dadbod completion source for these filetypes
          local cmp = require("cmp")
          local sources = cmp.get_config().sources
          table.insert(sources, { name = "vim-dadbod-completion" })
          cmp.setup.buffer({ sources = sources })
        end,
      })
    end,
  },

  -- SQL formatting
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Add SQL formatter
      opts.formatters_by_ft = vim.tbl_extend("force", opts.formatters_by_ft or {}, {
        sql = { "sql_formatter" },
      })
      
      opts.formatters = vim.tbl_extend("force", opts.formatters or {}, {
        sql_formatter = {
          command = "sql-formatter",
          args = { "--language", "postgresql" }, -- Change based on your DB
          stdin = true,
        },
      })
      
      return opts
    end,
  },

  -- Which-key integration for database keybindings
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local wk = require("which-key")
      wk.add({
        -- Database keybindings
        { "<leader>d", group = "database" },
        { "<leader>du", "<cmd>DBUIToggle<cr>", desc = "Toggle DB UI" },
        { "<leader>df", "<cmd>DBUIFindBuffer<cr>", desc = "Find DB buffer" },
        { "<leader>dr", "<cmd>DBUIRenameBuffer<cr>", desc = "Rename DB buffer" },
        { "<leader>dl", "<cmd>DBUILastQueryInfo<cr>", desc = "Last query info" },
        { "<leader>da", "<cmd>DBUIAddConnection<cr>", desc = "Add DB connection" },
        
        -- SQL specific bindings (only in SQL buffers)
        { mode = { "n", "v" }, "<leader>de", group = "execute", ft = { "sql", "mysql", "plsql" } },
        { mode = "n", "<leader>dee", "<Plug>(DBUI_ExecuteQuery)", desc = "Execute query", ft = { "sql", "mysql", "plsql" } },
        { mode = "v", "<leader>dee", "<Plug>(DBUI_ExecuteQuery)", desc = "Execute selection", ft = { "sql", "mysql", "plsql" } },
        { mode = "n", "<leader>des", "<Plug>(DBUI_SaveQuery)", desc = "Save query", ft = { "sql", "mysql", "plsql" } },
        { mode = "n", "<leader>dE", "<Plug>(DBUI_EditBindParameters)", desc = "Edit bind parameters", ft = { "sql", "mysql", "plsql" } },
      })
      
      return opts
    end,
  },

  -- Enhanced SQL language support
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Ensure SQL parser is installed
      vim.list_extend(opts.ensure_installed or {}, {
        "sql",
      })
      return opts
    end,
  },
}

-- Sample database connections can be added to your config:
-- In your init.lua or a separate config file:
--
-- vim.g.dbs = {
--   dev = 'postgres://username:password@localhost:5432/dbname',
--   staging = 'mysql://username:password@localhost:3306/dbname',
--   sqlite_example = 'sqlite:' .. vim.fn.expand('~/databases/example.db'),
-- }
--
-- Or use environment variables:
-- vim.g.dbs = {
--   dev = vim.env.DATABASE_URL,
--   prod = vim.env.PROD_DATABASE_URL,
-- }