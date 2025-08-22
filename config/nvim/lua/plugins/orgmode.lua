return {
  -- Modern org mode for Neovim
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = "org",
    config = function()
      -- Setup orgmode with cleaned configuration
      require("orgmode").setup({
        -- File locations
        org_agenda_files = { "~/org/**/*" },
        org_default_notes_file = "~/org/refile.org",
        
        -- TODO keywords with a GTD-style workflow
        org_todo_keywords = { "TODO(t)", "NEXT(n)", "WAITING(w)", "|", "DONE(d)", "CANCELLED(c)" },
        org_todo_keyword_faces = {
          TODO = ":foreground #ff79c6 :weight bold",
          NEXT = ":foreground #8be9fd :weight bold",
          WAITING = ":foreground #f1fa8c :weight bold",
          DONE = ":foreground #50fa7b :weight bold",
          CANCELLED = ":foreground #6272a4 :weight bold",
        },
        
        -- Visual settings
        org_hide_leading_stars = true,
        org_hide_emphasis_markers = true,
        org_ellipsis = " ▾",
        org_startup_folded = "content",
        
        -- Agenda settings
        org_agenda_start_on_weekday = 1, -- Monday
        org_agenda_span = "week",
        win_split_mode = "auto",
        
        -- Logging
        org_log_done = "time",
        org_log_into_drawer = "LOGBOOK",
        
        -- Capture templates
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
            template = "* MEETING with %? :meeting:\n  SCHEDULED: %t\n  - Attendees:\n  - Agenda:\n  - Notes:\n  %a",
            target = "~/org/meetings.org",
          },
        },
        
        -- Simplified keymappings (rely on keymaps.lua for consistency)
        mappings = {
          disable_all = false,
          global = {
            org_agenda = "<leader>oa",
            org_capture = "<leader>oc",
          },
          -- Let other mappings use defaults or be configured in keymaps.lua
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

  -- Org-roam: Zettelkasten-style note-taking for org-mode
  {
    "chipsenkbeil/org-roam.nvim",
    dependencies = {
      "nvim-orgmode/orgmode",
    },
    config = function()
      local roam = require("org-roam")
      roam.setup({
        directory = "~/sync/org/roam",
        
        -- Database settings
        database = {
          persist = false,  -- Disable persistence to avoid conflicts
          update_on_save = true,
        },
        
        -- Templates for regular notes
        templates = {
          d = {
            description = "default",
            template = "* %?",
            target = "%<%Y%m%d%H%M%S>-%[slug].org",
          },
        },
        
        -- Extensions configuration
        extensions = {
          dailies = {
            directory = "daily/",
            templates = {
              d = {
                description = "default",
                template = "* %<%I:%M %p>: %?",
                target = "%<%Y-%m-%d>.org",
                head = "#+title: %<%Y-%m-%d>\n#+filetags: :daily:\n\n",
              },
            },
          },
        },
        
        -- Disable default keybindings (we'll use our own)
        bindings = {
          add_alias = false,
          add_origin = false,
          capture_node = false,
          complete_node = false,
          find_node = false,
          goto_next_node = false,
          goto_prev_node = false,
          insert_node = false,
          remove_alias = false,
          remove_origin = false,
          toggle_roam_buffer = false,
          toggle_roam_buffer_fixed = false,
        },
      })
    end,
  },

  -- Note: Orgmode.nvim handles its own syntax highlighting
  -- Treesitter parser for org is not in the standard nvim-treesitter repo
  -- Orgmode completion is handled by blink.cmp in LazyVim
}