-- Git workflow enhancements with Magit-like interface
return {
  -- Neogit: Magit-like Git interface for Neovim
  {
    "NeogitOrg/neogit",
    enabled = true,
    dependencies = {
      "nvim-lua/plenary.nvim",         -- required
      "sindrets/diffview.nvim",        -- optional - Diff integration
      "folke/snacks.nvim",             -- optional - for picker UI
    },
    config = function()
      require("neogit").setup({
        -- Disable hints at the top of the status buffer
        disable_hint = false,
        -- Disable changing buffer highlights based on cursor position
        disable_context_highlighting = false,
        -- Disable signs for sections/items/hunks
        disable_signs = false,
        -- Auto-insert mode for empty commit messages
        disable_insert_on_commit = "auto",
        -- File watcher for auto-refresh
        filewatcher = {
          interval = 1000,
          enabled = true,
        },
        -- Graph style - kitty for better visual representation
        graph_style = "kitty",
        -- Use default keymaps
        use_default_keymaps = true,
        -- Auto refresh status buffer
        auto_refresh = true,
        -- Sort branches by commit date descending
        sort_branches = "-committerdate",
        -- Default way of opening neogit
        kind = "tab",
        -- Console output settings
        console_timeout = 2000,
        auto_show_console = true,
        auto_close_console = true,
        -- Status buffer settings
        status = {
          show_head_commit_hash = true,
          recent_commit_count = 10,
        },
        -- Commit editor settings
        commit_editor = {
          kind = "tab",
          show_staged_diff = true,
          staged_diff_split_kind = "split",
          spell_check = true,
        },
        -- Commit view settings
        commit_view = {
          kind = "vsplit",
          verify_commit = true, -- Enable signature verification
        },
        -- Git services for pull request creation
        git_services = {
          ["github.com"] = {
            commit = "https://github.com/${owner}/${repository}/commit/${commit_hash}",
            tree = "https://github.com/${owner}/${repository}/tree/${branch_name}",
            pull_request = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
          },
        },
        -- Integrations
        integrations = {
          diffview = true,     -- Enable diffview integration
          snacks = true,       -- Use snacks.picker for menu selection (preferred over telescope)
        },
        -- Sections configuration
        sections = {
          untracked = {
            folded = false,
            hidden = false,
          },
          unstaged = {
            folded = false,
            hidden = false,
          },
          staged = {
            folded = false,
            hidden = false,
          },
          stashes = {
            folded = true,
            hidden = false,
          },
          unpulled_upstream = {
            folded = true,
            hidden = false,
          },
          unmerged_upstream = {
            folded = false,
            hidden = false,
          },
          unpulled_pushRemote = {
            folded = true,
            hidden = false,
          },
          unmerged_pushRemote = {
            folded = false,
            hidden = false,
          },
          recent = {
            folded = true,
            hidden = false,
          },
        },
      })
    end,
  },

  -- Diffview: Enhanced diff viewing and merge conflict resolution
  {
    "sindrets/diffview.nvim",
    config = function()
      require("diffview").setup({
        diff_binaries = false,
        enhanced_diff_hl = true,
        git_cmd = { "git" },
        use_icons = true,
        show_help_hints = true,
        watch_index = true,
        icons = {
          folder_closed = "",
          folder_open = "",
        },
        signs = {
          fold_closed = "",
          fold_open = "",
          done = "✓",
        },
        view = {
          default = {
            layout = "diff2_horizontal",
            winbar_info = false,
          },
          merge_tool = {
            layout = "diff3_horizontal",
            disable_diagnostics = true,
            winbar_info = true,
          },
          file_history = {
            layout = "diff2_horizontal",
            winbar_info = false,
          },
        },
        file_panel = {
          listing_style = "tree",
          tree_options = {
            flatten_dirs = true,
            folder_statuses = "only_folded",
          },
          win_config = {
            position = "left",
            width = 35,
            win_opts = {}
          },
        },
        file_history_panel = {
          log_options = {
            git = {
              single_file = {
                max_count = 256,
                follow = false,
                all = false,
                merges = false,
                no_merges = false,
                reverse = false,
              },
              multi_file = {
                max_count = 256,
                follow = false,
                all = false,
                merges = false,
                no_merges = false,
                reverse = false,
              },
            },
          },
          win_config = {
            position = "bottom",
            height = 16,
            win_opts = {}
          },
        },
        commit_log_panel = {
          win_config = {
            win_opts = {},
          }
        },
        default_args = {
          DiffviewOpen = {},
          DiffviewFileHistory = {},
        },
        hooks = {
          diff_buf_read = function(bufnr)
            -- Change local options in diff buffers
            vim.opt_local.wrap = false
            vim.opt_local.list = false
            vim.opt_local.colorcolumn = { 80 }
          end,
          view_opened = function(view)
            -- Highlight 'DiffAdd', 'DiffChange', 'DiffDelete', etc.
          end,
        },
        keymaps = {
          disable_defaults = false,
          view = {
            { "n", "<tab>", require("diffview.actions").select_next_entry, { desc = "Open the diff for the next file" } },
            { "n", "<s-tab>", require("diffview.actions").select_prev_entry, { desc = "Open the diff for the previous file" } },
            { "n", "gf", require("diffview.actions").goto_file, { desc = "Open the file in the previous tabpage" } },
            { "n", "<C-w><C-f>", require("diffview.actions").goto_file_split, { desc = "Open the file in a new split" } },
            { "n", "<C-w>gf", require("diffview.actions").goto_file_tab, { desc = "Open the file in a new tabpage" } },
            { "n", "<leader>e", require("diffview.actions").focus_files, { desc = "Bring focus to the file panel" } },
            { "n", "<leader>b", require("diffview.actions").toggle_files, { desc = "Toggle the file panel" } },
            { "n", "g<C-x>", require("diffview.actions").cycle_layout, { desc = "Cycle through available layouts" } },
            { "n", "[x", require("diffview.actions").prev_conflict, { desc = "In the merge-tool: jump to the previous conflict" } },
            { "n", "]x", require("diffview.actions").next_conflict, { desc = "In the merge-tool: jump to the next conflict" } },
            { "n", "<leader>gmo", require("diffview.actions").conflict_choose("ours"), { desc = "Choose the OURS version of a conflict" } },
            { "n", "<leader>gmt", require("diffview.actions").conflict_choose("theirs"), { desc = "Choose the THEIRS version of a conflict" } },
            { "n", "<leader>gmb", require("diffview.actions").conflict_choose("base"), { desc = "Choose the BASE version of a conflict" } },
            { "n", "<leader>gma", require("diffview.actions").conflict_choose("all"), { desc = "Choose all the versions of a conflict" } },
            { "n", "dx", require("diffview.actions").conflict_choose("none"), { desc = "Delete the conflict region" } },
          },
          diff1 = {
            { "n", "g?", require("diffview.actions").help({ "view", "diff1" }), { desc = "Open the help panel" } },
          },
          diff2 = {
            { "n", "g?", require("diffview.actions").help({ "view", "diff2" }), { desc = "Open the help panel" } },
          },
          diff3 = {
            { "n", "g?", require("diffview.actions").help({ "view", "diff3" }), { desc = "Open the help panel" } },
          },
          diff4 = {
            { "n", "g?", require("diffview.actions").help({ "view", "diff4" }), { desc = "Open the help panel" } },
          },
          file_panel = {
            { "n", "j", require("diffview.actions").next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "<down>", require("diffview.actions").next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "k", require("diffview.actions").prev_entry, { desc = "Bring the cursor to the previous file entry" } },
            { "n", "<up>", require("diffview.actions").prev_entry, { desc = "Bring the cursor to the previous file entry" } },
            { "n", "<cr>", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "o", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "l", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "<2-LeftMouse>", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "-", require("diffview.actions").toggle_stage_entry, { desc = "Stage / unstage the selected entry" } },
            { "n", "S", require("diffview.actions").stage_all, { desc = "Stage all entries" } },
            { "n", "U", require("diffview.actions").unstage_all, { desc = "Unstage all entries" } },
            { "n", "X", require("diffview.actions").restore_entry, { desc = "Restore entry to the state on the left side" } },
            { "n", "L", require("diffview.actions").open_commit_log, { desc = "Open the commit log panel" } },
            { "n", "zo", require("diffview.actions").open_fold, { desc = "Expand fold" } },
            { "n", "h", require("diffview.actions").close_fold, { desc = "Collapse fold" } },
            { "n", "zc", require("diffview.actions").close_fold, { desc = "Collapse fold" } },
            { "n", "za", require("diffview.actions").toggle_fold, { desc = "Toggle fold" } },
            { "n", "zR", require("diffview.actions").open_all_folds, { desc = "Expand all folds" } },
            { "n", "zM", require("diffview.actions").close_all_folds, { desc = "Collapse all folds" } },
            { "n", "<c-b>", require("diffview.actions").scroll_view(-0.25), { desc = "Scroll the view up" } },
            { "n", "<c-f>", require("diffview.actions").scroll_view(0.25), { desc = "Scroll the view down" } },
            { "n", "<tab>", require("diffview.actions").select_next_entry, { desc = "Open the diff for the next file" } },
            { "n", "<s-tab>", require("diffview.actions").select_prev_entry, { desc = "Open the diff for the previous file" } },
            { "n", "gf", require("diffview.actions").goto_file, { desc = "Open the file in the previous tabpage" } },
            { "n", "<C-w><C-f>", require("diffview.actions").goto_file_split, { desc = "Open the file in a new split" } },
            { "n", "<C-w>gf", require("diffview.actions").goto_file_tab, { desc = "Open the file in a new tabpage" } },
            { "n", "i", require("diffview.actions").listing_style, { desc = "Toggle between 'list' and 'tree' views" } },
            { "n", "f", require("diffview.actions").toggle_flatten_dirs, { desc = "Flatten empty subdirectories in tree listing style" } },
            { "n", "R", require("diffview.actions").refresh_files, { desc = "Update stats and entries in the file list" } },
            { "n", "<leader>e", require("diffview.actions").focus_files, { desc = "Bring focus to the file panel" } },
            { "n", "<leader>b", require("diffview.actions").toggle_files, { desc = "Toggle the file panel" } },
            { "n", "g<C-x>", require("diffview.actions").cycle_layout, { desc = "Cycle through available layouts" } },
            { "n", "g?", require("diffview.actions").help("file_panel"), { desc = "Open the help panel" } },
          },
          file_history_panel = {
            { "n", "g!", require("diffview.actions").options, { desc = "Open the option panel" } },
            { "n", "<C-A-d>", require("diffview.actions").open_in_diffview, { desc = "Open the entry under the cursor in a diffview" } },
            { "n", "y", require("diffview.actions").copy_hash, { desc = "Copy the commit hash of the entry under the cursor" } },
            { "n", "L", require("diffview.actions").open_commit_log, { desc = "Show commit details" } },
            { "n", "zR", require("diffview.actions").open_all_folds, { desc = "Expand all folds" } },
            { "n", "zM", require("diffview.actions").close_all_folds, { desc = "Collapse all folds" } },
            { "n", "j", require("diffview.actions").next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "<down>", require("diffview.actions").next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "k", require("diffview.actions").prev_entry, { desc = "Bring the cursor to the previous file entry" } },
            { "n", "<up>", require("diffview.actions").prev_entry, { desc = "Bring the cursor to the previous file entry" } },
            { "n", "<cr>", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "o", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "<2-LeftMouse>", require("diffview.actions").select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "<c-b>", require("diffview.actions").scroll_view(-0.25), { desc = "Scroll the view up" } },
            { "n", "<c-f>", require("diffview.actions").scroll_view(0.25), { desc = "Scroll the view down" } },
            { "n", "<tab>", require("diffview.actions").select_next_entry, { desc = "Open the diff for the next file" } },
            { "n", "<s-tab>", require("diffview.actions").select_prev_entry, { desc = "Open the diff for the previous file" } },
            { "n", "gf", require("diffview.actions").goto_file, { desc = "Open the file in the previous tabpage" } },
            { "n", "<C-w><C-f>", require("diffview.actions").goto_file_split, { desc = "Open the file in a new split" } },
            { "n", "<C-w>gf", require("diffview.actions").goto_file_tab, { desc = "Open the file in a new tabpage" } },
            { "n", "<leader>e", require("diffview.actions").focus_files, { desc = "Bring focus to the file panel" } },
            { "n", "<leader>b", require("diffview.actions").toggle_files, { desc = "Toggle the file panel" } },
            { "n", "g<C-x>", require("diffview.actions").cycle_layout, { desc = "Cycle through available layouts" } },
            { "n", "g?", require("diffview.actions").help("file_history_panel"), { desc = "Open the help panel" } },
          },
          option_panel = {
            { "n", "<tab>", require("diffview.actions").select_entry, { desc = "Change the current option" } },
            { "n", "q", require("diffview.actions").close, { desc = "Close the panel" } },
            { "n", "g?", require("diffview.actions").help("option_panel"), { desc = "Open the help panel" } },
          },
          help_panel = {
            { "n", "q", require("diffview.actions").close, { desc = "Close help menu" } },
            { "n", "<esc>", require("diffview.actions").close, { desc = "Close help menu" } },
          },
        },
      })
    end,
  },
}