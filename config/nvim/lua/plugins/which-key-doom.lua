return {
  "folke/which-key.nvim",
  opts_extend = { "spec" },
  opts = {
    preset = "modern",
    delay = 300,
    win = {
      border = "rounded",
      padding = { 1, 2 },
      title = true,
      title_pos = "center",
      zindex = 1000,
    },
    spec = {
      -- Add only groups that LazyVim doesn't already define
      { "<leader>o", group = "open/apps" },
      { "<leader>ot", group = "terminal" },
      { "<leader>ct", group = "code/test" },
      { "<leader>gm", group = "git/merge" },
      { "<leader>n", group = "notes" },
      { "<leader>i", group = "insert" },
      { "<leader>e", group = "error" },
      { "<leader>m", group = "local leader" },
      { "<leader>r", group = "refactor" },
      { "<leader>v", group = "version control" },
      { "<leader>T", group = "treesitter" },
      { "<leader>t", group = "todo" },
      { "<leader>j", group = "jump/harpoon" },
      { "<leader>y", group = "yank" },
    },
  },
}