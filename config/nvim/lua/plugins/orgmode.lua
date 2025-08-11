return {
  -- Modern org mode for Neovim
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = "org",
    config = function()
      -- Setup orgmode
      require("orgmode").setup({
        org_agenda_files = { "~/org/**/*", "~/Documents/org/**/*" },
        org_default_notes_file = "~/org/refile.org",
        org_todo_keywords = { "TODO(t)", "NEXT(n)", "WAITING(w)", "|", "DONE(d)", "CANCELLED(c)" },
        org_todo_keyword_faces = {
          TODO = ":foreground #ff79c6 :weight bold",
          NEXT = ":foreground #8be9fd :weight bold",
          WAITING = ":foreground #f1fa8c :weight bold",
          DONE = ":foreground #50fa7b :weight bold",
          CANCELLED = ":foreground #6272a4 :weight bold",
        },
        org_hide_leading_stars = true,
        org_hide_emphasis_markers = true,
        org_agenda_start_on_weekday = 1,
        org_capture_templates = {
          t = {
            description = "Task",
            template = "* TODO %?\n  SCHEDULED: %t\n  %a",
            target = "~/org/tasks.org",
          },
          n = {
            description = "Note",
            template = "* %?\n  %U\n  %a",
            target = "~/org/notes.org",
          },
          m = {
            description = "Meeting",
            template = "* MEETING with %? :meeting:\n  SCHEDULED: %t\n  %a",
            target = "~/org/meetings.org",
          },
          i = {
            description = "Idea",
            template = "* %?\n  %U\n  %a",
            target = "~/org/ideas.org",
          },
        },
        org_agenda_templates = {
          t = { description = "Today", template = "a" },
          w = { description = "Week view", template = "w" },
        },
        win_split_mode = "tabnew",
        org_log_done = "time",
        org_agenda_span = "week",
        org_ellipsis = " ▾",
        org_startup_folded = "showeverything",
        org_blank_before_new_entry = {
          heading = true,
          plain_list_item = false,
        },
        mappings = {
          disable_all = false,
          global = {
            org_agenda = "<leader>oa",
            org_capture = "<leader>oc",
          },
          org = {
            org_toggle_checkbox = "<leader>mx",
            org_todo = "<leader>mt",
            org_todo_prev = "<leader>mT",
            org_open_at_point = "<leader>mo",
            org_cycle = "<TAB>",
            org_global_cycle = "<S-TAB>",
            org_archive_subtree = "<leader>ma",
            org_set_tags_command = "<leader>m:",
            org_toggle_archive_tag = "<leader>mA",
            org_do_promote = "<leader>mh",
            org_do_demote = "<leader>ml",
            org_promote_subtree = "<leader>mH",
            org_demote_subtree = "<leader>mL",
            org_meta_return = "<leader>mRET",
            org_insert_heading_respect_content = "<leader>mir",
            org_insert_todo_heading = "<leader>mit",
            org_insert_todo_heading_respect_content = "<leader>miT",
            org_insert_link = "<leader>mil",
            org_next_link = "<leader>mn",
            org_previous_link = "<leader>mp",
            org_store_link = "<leader>ms",
            org_time_stamp = "<leader>m.",
            org_time_stamp_inactive = "<leader>m!",
            org_deadline = "<leader>md",
            org_schedule = "<leader>ms",
            org_refile = "<leader>mr",
            org_export = "<leader>me",
            org_toggle_heading = "<leader>m*",
          },
          capture = {
            org_capture_finalize = "<leader>,",
            org_capture_refile = "<leader>r",
            org_capture_kill = "<leader>k",
          },
          agenda = {
            org_agenda_later = "f",
            org_agenda_earlier = "b",
            org_agenda_goto_today = ".",
            org_agenda_day_view = "vd",
            org_agenda_week_view = "vw",
            org_agenda_month_view = "vm",
            org_agenda_year_view = "vy",
            org_agenda_quit = "q",
            org_agenda_switch_to = "<CR>",
            org_agenda_goto = "<TAB>",
            org_agenda_goto_date = "J",
            org_agenda_redo = "r",
            org_agenda_todo = "t",
            org_agenda_open = "o",
            org_agenda_set_tags = ":",
            org_agenda_deadline = "<leader>d",
            org_agenda_schedule = "<leader>s",
            org_agenda_archive = "<leader>a",
          },
        },
      })
    end,
  },

  -- Table support
  {
    "dhruvasagar/vim-table-mode",
    ft = { "org", "markdown" },
    config = function()
      vim.g.table_mode_corner = "|"
      vim.g.table_mode_corner_corner = "|"
      vim.g.table_mode_header_fillchar = "-"
    end,
  },

  -- Calendar integration
  {
    "mattn/calendar-vim",
    cmd = "Calendar",
  },

  -- Note: Orgmode completion is handled by blink.cmp in LazyVim
}