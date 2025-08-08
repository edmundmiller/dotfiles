-- Doom Emacs-style org-roam keybindings for Obsidian.nvim
return {
  "epwalsh/obsidian.nvim",
  keys = {
    -- Note operations (Doom: SPC n r ...)
    { "<leader>nrf", "<cmd>ObsidianQuickSwitch<cr>", desc = "Find note" },
    { "<leader>nrF", "<cmd>ObsidianSearch<cr>", desc = "Find note (content)" },
    { "<leader>nri", "<cmd>ObsidianNew<cr>", desc = "Insert new note" },
    { "<leader>nrI", "<cmd>ObsidianLinkNew<cr>", desc = "Insert new note (with title)" },
    { "<leader>nrr", "<cmd>ObsidianRename<cr>", desc = "Rename note" },
    { "<leader>nrd", "<cmd>ObsidianDailies<cr>", desc = "Daily notes" },
    { "<leader>nrt", "<cmd>ObsidianToday<cr>", desc = "Today's daily note" },
    { "<leader>nry", "<cmd>ObsidianYesterday<cr>", desc = "Yesterday's daily note" },
    { "<leader>nrT", "<cmd>ObsidianTomorrow<cr>", desc = "Tomorrow's daily note" },
    { "<leader>nrg", "<cmd>ObsidianTags<cr>", desc = "Find by tag" },
    { "<leader>nrb", "<cmd>ObsidianBacklinks<cr>", desc = "Show backlinks" },
    { "<leader>nrl", "<cmd>ObsidianLinks<cr>", desc = "Show links" },
    { "<leader>nro", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian app" },
    { "<leader>nrn", "<cmd>ObsidianNew<cr>", desc = "New note" },
    { "<leader>nrN", "<cmd>ObsidianNewFromTemplate<cr>", desc = "New note from template" },
    { "<leader>nrx", "<cmd>ObsidianExtractNote<cr>", desc = "Extract note", mode = "v" },
    { "<leader>nrc", "<cmd>ObsidianToggleCheckbox<cr>", desc = "Toggle checkbox" },
    { "<leader>nrp", "<cmd>ObsidianPasteImg<cr>", desc = "Paste image" },
    { "<leader>nrP", "<cmd>ObsidianTemplate<cr>", desc = "Insert template" },
    
    -- Workspace operations
    { "<leader>nrw", "<cmd>ObsidianWorkspace<cr>", desc = "Switch workspace" },
    
    -- Quick access aliases (Doom style)
    { "<leader>nr<leader>", "<cmd>ObsidianQuickSwitch<cr>", desc = "Find note (quick)" },
    { "<leader>nrSPC", "<cmd>ObsidianQuickSwitch<cr>", desc = "Find note (quick)" },
  },
  config = function(_, opts)
    require("obsidian").setup(opts)
    
    -- Set up which-key groups
    local wk = require("which-key")
    wk.add({
      { "<leader>n", group = "notes" },
      { "<leader>nr", group = "roam (obsidian)" },
    })
  end,
}