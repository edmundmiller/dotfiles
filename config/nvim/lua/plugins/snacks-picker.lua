-- Snacks.nvim picker configuration with ivy-style layout
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = vim.tbl_deep_extend("force", opts.picker or {}, {
      -- Use ivy preset layout
      layout = {
        preset = "ivy",
      },
    })
    return opts
  end,
  keys = {
    -- Picker keybindings (Doom-style)
    { "<leader>ff", function() require("snacks").picker.files() end, desc = "Find files" },
    { "<leader>fg", function() require("snacks").picker.grep() end, desc = "Find text (grep)" },
    { "<leader>fr", function() require("snacks").picker.recent() end, desc = "Recent files" },
    { "<leader>fb", function() require("snacks").picker.buffers() end, desc = "Find buffers" },
    { "<leader>fh", function() require("snacks").picker.help() end, desc = "Find help" },
    { "<leader>fc", function() require("snacks").picker.commands() end, desc = "Find commands" },
    { "<leader>fk", function() require("snacks").picker.keymaps() end, desc = "Find keymaps" },
    { "<leader>fo", function() require("snacks").picker.oldfiles() end, desc = "Find old files" },
    { "<leader>fq", function() require("snacks").picker.quickfix() end, desc = "Find quickfix" },
    { "<leader>fl", function() require("snacks").picker.loclist() end, desc = "Find loclist" },
    
    -- Git pickers
    { "<leader>gf", function() require("snacks").picker.git_files() end, desc = "Git files" },
    { "<leader>gs", function() require("snacks").picker.git_status() end, desc = "Git status" },
    { "<leader>gc", function() require("snacks").picker.git_commits() end, desc = "Git commits" },
    { "<leader>gb", function() require("snacks").picker.git_branches() end, desc = "Git branches" },
  },
}