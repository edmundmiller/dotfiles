-- TaskNotes integration for task management with markdown files
-- Each task is a markdown file with YAML frontmatter
return {
  {
    "edmundmiller/tasknotes.nvim",
    dev = true, -- Use local ~/src/emacs/tasknotes.nvim when available
    dependencies = {
      "MunifTanjim/nui.nvim", -- Required for UI components
      "nvim-telescope/telescope.nvim", -- Optional but recommended for browsing
      "nvim-lua/plenary.nvim", -- Optional but recommended
    },
    opts = {
      -- Path to TaskNotes vault directory
      vault_path = vim.fn.expand("~/sync/claude-vault"),

      -- Task identification method
      task_identification_method = "property", -- "tag" or "property"
      task_property_name = "type",
      task_property_value = "task",

      -- Use default field mapping, statuses, and priorities
      -- See README.md for customization options

      -- UI configuration
      ui = {
        border_style = "rounded",
      },

      -- Telescope configuration
      telescope = {
        enabled = true,
        theme = "dropdown",
      },

      -- Time tracking
      time_tracking = {
        enabled = true,
        auto_save_interval = 60, -- seconds
      },

      -- Keymaps (using plugin defaults)
      keymaps = {
        browse = "<leader>tb",
        new_task = "<leader>tn",
        edit_task = "<leader>te",
        toggle_timer = "<leader>tt",
      },
    },
    cmd = {
      -- Core commands
      "TaskNotesBrowse",
      "TaskNotesNew",
      "TaskNotesEdit",
      "TaskNotesRescan",

      -- Time tracking commands
      "TaskNotesTimerToggle",
      "TaskNotesTimerStatus",
      "TaskNotesTimeEntries",

      -- Filtered browsing commands
      "TaskNotesByStatus",
      "TaskNotesByPriority",
      "TaskNotesByContext",
    },
    keys = {
      { "<leader>tb", desc = "Browse tasks" },
      { "<leader>tn", desc = "New task" },
      { "<leader>te", desc = "Edit task" },
      { "<leader>tt", desc = "Toggle timer" },
    },
  },
}
