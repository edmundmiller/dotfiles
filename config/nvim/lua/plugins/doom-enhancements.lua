-- Additional plugins to enhance Doom Emacs-like experience
return {
  -- Oil.nvim for directory browsing (like dired)
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("oil").setup({
        default_file_explorer = true,
        delete_to_trash = true,
        skip_confirm_for_simple_edits = true,
        view_options = {
          show_hidden = true,
          is_always_hidden = function(name, _)
            return name == ".." or name == ".git"
          end,
        },
        keymaps = {
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-s>"] = "actions.select_vsplit",
          ["<C-h>"] = "actions.select_split",
          ["<C-t>"] = "actions.select_tab",
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["<C-l>"] = "actions.refresh",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = "actions.tcd",
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
          ["g\\"] = "actions.toggle_trash",
        },
      })
    end,
  },

  -- Spectre for search and replace (like Doom's search/replace)
  {
    "nvim-pack/nvim-spectre",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("spectre").setup({
        color_devicons = true,
        open_cmd = "vnew",
        live_update = false,
        line_sep_start = "┌─────────────────────────────────────────",
        result_padding = "│  ",
        line_sep = "└─────────────────────────────────────────",
        highlight = {
          ui = "String",
          search = "DiffChange",
          replace = "DiffDelete",
        },
        mapping = {
          ["toggle_line"] = {
            map = "dd",
            cmd = "<cmd>lua require('spectre').toggle_line()<CR>",
            desc = "toggle current item",
          },
          ["enter_file"] = {
            map = "<cr>",
            cmd = "<cmd>lua require('spectre.actions').select_entry()<CR>",
            desc = "goto current file",
          },
          ["send_to_qf"] = {
            map = "<leader>q",
            cmd = "<cmd>lua require('spectre.actions').send_to_qf()<CR>",
            desc = "send all item to quickfix",
          },
          ["replace_cmd"] = {
            map = "<leader>c",
            cmd = "<cmd>lua require('spectre.actions').replace_cmd()<CR>",
            desc = "input replace vim command",
          },
          ["show_option_menu"] = {
            map = "<leader>o",
            cmd = "<cmd>lua require('spectre').show_options()<CR>",
            desc = "show option",
          },
          ["run_current_replace"] = {
            map = "<leader>rc",
            cmd = "<cmd>lua require('spectre.actions').run_current_replace()<CR>",
            desc = "replace current line",
          },
          ["run_replace"] = {
            map = "<leader>R",
            cmd = "<cmd>lua require('spectre.actions').run_replace()<CR>",
            desc = "replace all",
          },
          ["change_view_mode"] = {
            map = "<leader>v",
            cmd = "<cmd>lua require('spectre').change_view()<CR>",
            desc = "change result view mode",
          },
          ["change_replace_sed"] = {
            map = "trs",
            cmd = "<cmd>lua require('spectre').change_engine_replace('sed')<CR>",
            desc = "use sed to replace",
          },
          ["change_replace_oxi"] = {
            map = "tro",
            cmd = "<cmd>lua require('spectre').change_engine_replace('oxi')<CR>",
            desc = "use oxi to replace",
          },
          ["toggle_live_update"] = {
            map = "tu",
            cmd = "<cmd>lua require('spectre').toggle_live_update()<CR>",
            desc = "update change when vim write file.",
          },
          ["toggle_ignore_case"] = {
            map = "ti",
            cmd = "<cmd>lua require('spectre').change_options('ignore-case')<CR>",
            desc = "toggle ignore case",
          },
          ["toggle_ignore_hidden"] = {
            map = "th",
            cmd = "<cmd>lua require('spectre').change_options('hidden')<CR>",
            desc = "toggle search hidden",
          },
          ["resume_last_search"] = {
            map = "<leader>l",
            cmd = "<cmd>lua require('spectre').resume_last_search()<CR>",
            desc = "resume last search before close",
          },
        },
      })
    end,
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    opts = {
      manual_mode = false,
      detection_methods = { "lsp", "pattern" },
      patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
      ignore_lsp = {},
      exclude_dirs = {},
      show_hidden = false,
      silent_chdir = true,
      scope_chdir = "global",
      datapath = vim.fn.stdpath("data"),
    },
    event = "VeryLazy",
    config = function(_, opts)
      require("project_nvim").setup(opts)
      require("telescope").load_extension("projects")
    end,
    keys = {
      { "<leader>fp", "<Cmd>Telescope projects<CR>", desc = "Projects" },
    },
  },

  -- Better quickfix window
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    config = function()
      require("bqf").setup({
        auto_enable = true,
        auto_resize_height = true,
        preview = {
          win_height = 12,
          win_vheight = 12,
          delay_syntax = 80,
          border_chars = { "┃", "━", "┏", "┓", "┗", "┛", "━", "┃", "█" },
          should_preview_cb = function(bufnr, qwinid)
            local ret = true
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local fsize = vim.fn.getfsize(bufname)
            if fsize > 100 * 1024 then
              -- skip file size greater than 100k
              ret = false
            elseif bufname:match("^fugitive://") then
              -- skip fugitive buffer
              ret = false
            end
            return ret
          end,
        },
        func_map = {
          drop = "o",
          openc = "O",
          split = "<C-s>",
          tabdrop = "<C-t>",
          tabc = "",
          ptogglemode = "z,",
        },
        filter = {
          fzf = {
            action_for = { ["ctrl-s"] = "split", ["ctrl-t"] = "tab drop" },
            extra_opts = { "--bind", "ctrl-o:toggle-all", "--prompt", "> " },
          },
        },
      })
    end,
  },

  -- Configure snacks.nvim zen mode (LazyVim default) with Ghostty font support
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local function ghostty_font_change(increment)
        if not vim.env.GHOSTTY_RESOURCES_DIR then
          return
        end
        
        local stdout = vim.loop.new_tty(1, false)
        if stdout then
          -- Send OSC sequence for Ghostty font changes
          stdout:write(string.format("\x1b]1337;ZenMode=%s;FontChange=%d\x07", 
            increment > 0 and "on" or "off", math.abs(increment)))
          stdout:write(string.format("\x1b]777;notify;Zen Mode;Font size %s\x07",
            increment > 0 and "increased" or "restored"))
        end
      end

      opts.zen = opts.zen or {}
      opts.zen.toggles = {
        dim = true,
        git_signs = false,
        mini_diff_signs = false,
      }
      opts.zen.show = {
        statusline = false,
        tabline = false,
      }
      opts.zen.win = {
        width = 120,
        height = 0,
      }
      opts.zen.on_open = function()
        -- Increase font size for GUI Neovim
        if vim.g.neovide then
          vim.g.neovide_scale_factor = (vim.g.neovide_scale_factor or 1.0) * 1.25
        end
        -- Increase font size using Neovim's guifont option (with error handling)
        pcall(function()
          local current_font = vim.opt.guifont:get()
          if current_font and type(current_font) == "string" and current_font ~= "" then
            local font_name, size = current_font:match("([^:]+):h(%d+)")
            if font_name and size then
              vim.opt.guifont = font_name .. ":h" .. (tonumber(size) + 4)
            end
          end
        end)
        -- Ghostty font increase
        ghostty_font_change(4)
      end
      opts.zen.on_close = function()
        -- Restore font size for GUI Neovim
        if vim.g.neovide then
          vim.g.neovide_scale_factor = (vim.g.neovide_scale_factor or 1.0) / 1.25
        end
        -- Restore original font size (with error handling)
        pcall(function()
          local current_font = vim.opt.guifont:get()
          if current_font and type(current_font) == "string" and current_font ~= "" then
            local font_name, size = current_font:match("([^:]+):h(%d+)")
            if font_name and size then
              vim.opt.guifont = font_name .. ":h" .. (tonumber(size) - 4)
            end
          end
        end)
        -- Ghostty font restore
        ghostty_font_change(-4)
      end
      return opts
    end,
    keys = {
      { "<leader>tz", function() Snacks.zen() end, desc = "Toggle Zen Mode" },
    },
  },

  -- Better fold text
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    config = function()
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      require("ufo").setup({
        provider_selector = function(bufnr, filetype, buftype)
          return { "treesitter", "indent" }
        end,
      })
    end,
    keys = {
      {
        "zR",
        function()
          require("ufo").openAllFolds()
        end,
        desc = "Open all folds",
      },
      {
        "zM",
        function()
          require("ufo").closeAllFolds()
        end,
        desc = "Close all folds",
      },
    },
  },
}