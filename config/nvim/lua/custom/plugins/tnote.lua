return {
  dir = vim.fn.expand("~/src/personal/tnote/main/packages/nvim"),
  name = "tnote.nvim",
  config = function()
    require("tnote").setup({
      -- vault = "~/obsidian-vault",  -- auto-detected from ~/.config/tn/config.toml
      list = { limit = 50 },
    })
  end,
  keys = {
    { "<leader>tt", "<cmd>Tnote<CR>",    desc = "tnote: toggle task list" },
    { "<leader>ta", "<cmd>TnoteAdd<CR>", desc = "tnote: add task" },
  },
}
