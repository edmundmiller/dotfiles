-- Orgmode configuration - Emacs Orgmode clone for Neovim
-- https://github.com/nvim-orgmode/orgmode

---@type LazySpec
return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      -- Setup orgmode
      require("orgmode").setup({
        org_agenda_files = "~/sync/org/beorg/**/*",
        org_default_notes_file = "~/sync/org/inbox.org",

        -- Optional: Configure additional settings
        org_hide_leading_stars = true,
        org_agenda_start_on_weekday = 1, -- Monday
        org_deadline_warning_days = 14,

        -- Org-roam directory (for roam-style note taking)
        -- Note: nvim-orgmode doesn't have built-in roam support yet
        -- This is just a convention for organizing roam files
        -- Consider using org-roam.nvim plugin for full roam features
        -- org_roam_directory = "~/sync/org/roam",

        -- Optional: Customize TODO keywords
        -- org_todo_keywords = { "TODO", "NEXT", "|", "DONE" },

        -- Vim-style keybindings
        mappings = {
          -- Global mappings (available everywhere)
          global = {
            org_agenda = "<leader>oa",
            org_capture = "<leader>oc",
          },

          -- Org file mappings (in .org files)
          org = {
            org_meta_return = "<leader><CR>", -- Add heading/item/checkbox
            org_insert_heading_respect_content = "<leader>oih", -- Insert heading
            org_insert_todo_heading = "<leader>oiT", -- Insert TODO heading
            org_insert_todo_heading_respect_content = "<leader>oit",
            org_move_subtree_up = "gK", -- Vim-style: move subtree up
            org_move_subtree_down = "gJ", -- Vim-style: move subtree down
            org_do_promote = "<<", -- Promote heading
            org_do_demote = ">>", -- Demote heading
            org_promote_subtree = "<s", -- Promote subtree
            org_demote_subtree = ">s", -- Demote subtree
            org_todo = "cit", -- Change TODO state (vim-style "change in todo")
            org_todo_prev = "ciT", -- Previous TODO state
            org_toggle_checkbox = "<C-space>",
            org_open_at_point = "gx", -- Vim-style: go/execute
            org_cycle = "<TAB>", -- Fold current heading
            org_global_cycle = "<S-TAB>", -- Fold all
            org_archive_subtree = "<leader>o$", -- Archive
            org_set_tags_command = "<leader>ot", -- Set tags
            org_toggle_archive_tag = "<leader>oA",
            org_toggle_heading = "<leader>o*",
            org_timestamp_up = "<C-a>", -- Vim-style increment
            org_timestamp_down = "<C-x>", -- Vim-style decrement
            org_change_date = "cid", -- Change in date
            org_priority = "<leader>op", -- Set priority
            org_priority_up = "g<Up>",
            org_priority_down = "g<Down>",
            org_schedule = "<leader>os", -- Schedule
            org_deadline = "<leader>od", -- Set deadline
            org_time_stamp = "<leader>oi.", -- Insert timestamp
            org_time_stamp_inactive = "<leader>oi!", -- Insert inactive timestamp
            org_clock_in = "<leader>oxi", -- Clock in
            org_clock_out = "<leader>oxo", -- Clock out
            org_clock_cancel = "<leader>oxq", -- Cancel clock
            org_clock_goto = "<leader>oxj", -- Jump to clocked item
            org_set_effort = "<leader>oe", -- Set effort estimate
            org_show_help = "g?", -- Show help
            org_refile = "<leader>or", -- Refile
            org_store_link = "<leader>ol", -- Store link
            org_insert_link = "<leader>oL", -- Insert link
          },

          -- Agenda view mappings
          agenda = {
            org_agenda_later = "f", -- Forward in time
            org_agenda_earlier = "b", -- Backward in time
            org_agenda_goto_today = ".", -- Today
            org_agenda_day_view = "vd", -- Day view
            org_agenda_week_view = "vw", -- Week view
            org_agenda_month_view = "vm", -- Month view
            org_agenda_year_view = "vy", -- Year view
            org_agenda_quit = "q", -- Vim-style quit
            org_agenda_switch_to = "<CR>", -- Open in current window
            org_agenda_goto = "<TAB>", -- Open in split
            org_agenda_goto_date = "J", -- Jump to date
            org_agenda_redo = "r", -- Refresh
            org_agenda_todo = "t", -- Change TODO state
            org_agenda_clock_in = "I", -- Clock in
            org_agenda_clock_out = "O", -- Clock out
            org_agenda_clock_cancel = "X",
            org_agenda_priority = ",", -- Set priority
            org_agenda_priority_up = "+",
            org_agenda_priority_down = "-",
            org_agenda_archive = "$", -- Archive
            org_agenda_toggle_archive_tag = "A",
            org_agenda_set_tags = ":",
            org_agenda_deadline = "d", -- Set deadline
            org_agenda_schedule = "s", -- Schedule
            org_agenda_filter = "/", -- Filter
            org_agenda_refile = "r",
            org_agenda_show_help = "g?",
          },

          -- Capture mappings
          capture = {
            org_capture_finalize = "<C-c>", -- Save capture
            org_capture_refile = "<leader>or", -- Refile capture
            org_capture_kill = "<leader>ok", -- Discard capture
            org_capture_show_help = "g?",
          },
        },
      })

      -- Optional: Setup completion with nvim-cmp if needed
      -- Since you're using blink.cmp, you may need to configure completion separately
      -- or use the built-in orgmode completion
    end,
  },
}
