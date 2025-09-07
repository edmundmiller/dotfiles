-- Terminal and REPL integration for enhanced development workflow
return {
  -- ToggleTerm: Persistent terminal management
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      persist_mode = true,
      direction = "horizontal",
      close_on_exit = true,
      shell = vim.o.shell,
      auto_scroll = true,
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
      winbar = {
        enabled = false,
        name_formatter = function(term)
          return term.name
        end,
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      
      -- Custom terminal functions
      local Terminal = require("toggleterm.terminal").Terminal
      
      -- Lazygit terminal
      local lazygit = Terminal:new({
        cmd = "lazygit",
        dir = "git_dir",
        direction = "float",
        float_opts = {
          border = "double",
        },
        on_open = function(term)
          vim.cmd("startinsert!")
        end,
        on_close = function(term)
          vim.cmd("startinsert!")
        end,
      })
      
      -- Python REPL
      local python_repl = Terminal:new({
        cmd = "python3",
        direction = "horizontal",
        close_on_exit = false,
        hidden = true,
      })
      
      -- R REPL
      local r_repl = Terminal:new({
        cmd = "R",
        direction = "horizontal",
        close_on_exit = false,
        hidden = true,
      })
      
      -- Nextflow terminal
      local nextflow_term = Terminal:new({
        cmd = vim.o.shell,
        direction = "horizontal",
        close_on_exit = false,
        hidden = true,
        on_open = function(term)
          vim.cmd("startinsert!")
          -- Set up environment for Nextflow
          vim.api.nvim_chan_send(term.job_id, "echo 'Nextflow Terminal Ready'\n")
        end,
      })
      
      -- Create global functions for terminals
      function _LAZYGIT_TOGGLE()
        lazygit:toggle()
      end
      
      function _PYTHON_REPL_TOGGLE()
        python_repl:toggle()
      end
      
      function _R_REPL_TOGGLE()
        r_repl:toggle()
      end
      
      function _NEXTFLOW_TERM_TOGGLE()
        nextflow_term:toggle()
      end
    end,
  },

  -- Iron.nvim: REPL integration for multiple languages
  {
    "hkupty/iron.nvim",
    config = function()
      local iron = require("iron.core")
      
      iron.setup({
        config = {
          scratch_repl = true,
          repl_definition = {
            python = {
              command = { "python3" },
              format = require("iron.fts.common").bracketed_paste,
            },
            r = {
              command = { "R" },
            },
            julia = {
              command = { "julia" },
            },
            lua = {
              command = { "lua" },
            },
            nextflow = {
              command = { "nextflow", "console" },
            },
          },
          repl_open_cmd = require("iron.view").split.vertical.botright(0.4),
        },
        keymaps = {
          send_motion = "<space>sc",
          visual_send = "<space>sc",
          send_file = "<space>sf",
          send_line = "<space>sl",
          send_until_cursor = "<space>su",
          send_mark = "<space>sm",
          mark_motion = "<space>mc",
          mark_visual = "<space>mc",
          remove_mark = "<space>md",
          cr = "<space>s<cr>",
          interrupt = "<space>s<space>",
          exit = "<space>sq",
          clear = "<space>cl",
        },
        highlight = {
          italic = true,
        },
        ignore_blank_lines = true,
      })
    end,
  },

  -- Which-key integration for terminal and REPL keybindings
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local wk = require("which-key")
      wk.add({
        -- Terminal keybindings
        { "<leader>ot", group = "open/terminal" },
        { "<leader>ott", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
        { "<leader>otf", "<cmd>ToggleTerm direction=float<cr>", desc = "Float terminal" },
        { "<leader>oth", "<cmd>ToggleTerm size=15 direction=horizontal<cr>", desc = "Horizontal terminal" },
        { "<leader>otv", "<cmd>ToggleTerm size=80 direction=vertical<cr>", desc = "Vertical terminal" },
        { "<leader>otg", "<cmd>lua _LAZYGIT_TOGGLE()<cr>", desc = "LazyGit terminal" },
        
        -- REPL keybindings
        { "<leader>r", group = "repl" },
        { "<leader>rp", "<cmd>lua _PYTHON_REPL_TOGGLE()<cr>", desc = "Python REPL" },
        { "<leader>rr", "<cmd>lua _R_REPL_TOGGLE()<cr>", desc = "R REPL" },
        { "<leader>rn", "<cmd>lua _NEXTFLOW_TERM_TOGGLE()<cr>", desc = "Nextflow terminal" },
        { "<leader>ri", "<cmd>IronRepl<cr>", desc = "Iron REPL" },
        { "<leader>rR", "<cmd>IronRestart<cr>", desc = "Restart REPL" },
        { "<leader>rf", "<cmd>IronFocus<cr>", desc = "Focus REPL" },
        { "<leader>rh", "<cmd>IronHide<cr>", desc = "Hide REPL" },
        
        -- Send to REPL (visual mode)
        { mode = "v", "<leader>s", group = "send to repl" },
      })
      
      -- Terminal mode keybindings
      vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], { desc = "Navigate left" })
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], { desc = "Navigate down" })
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], { desc = "Navigate up" })
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], { desc = "Navigate right" })
      
      -- Quick terminal access
      vim.keymap.set("n", "<C-`>", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
      vim.keymap.set("t", "<C-`>", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
      
      -- Terminal send commands
      vim.keymap.set("n", "<leader>ots", function()
        local line = vim.api.nvim_get_current_line()
        require("toggleterm").send_lines_to_terminal("single_line", true, { args = vim.v.count })
      end, { desc = "Send line to terminal" })
      
      vim.keymap.set("v", "<leader>ots", function()
        require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count })
      end, { desc = "Send selection to terminal" })
      
      return opts
    end,
  },
}