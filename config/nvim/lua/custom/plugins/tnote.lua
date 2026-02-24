local tnote_dir = vim.fn.expand '~/src/personal/tnote/main/packages/nvim'

-- Optional local dev plugin. Skip cleanly on machines without this path.
if vim.fn.isdirectory(tnote_dir) == 0 then
  return {}
end

return {
  dir = tnote_dir,
  name = "tnote.nvim",
  -- Load on keymap OR when entering markdown files (for auto-open)
  ft = "markdown",
  config = function()
    require("tnote").setup({
      -- vault = "~/obsidian-vault",  -- auto-detected from ~/.config/tn/config.toml
      list = { limit = 50 },
      auto_open = {
        enabled = true,
        trigger = "vault", -- "vault" for all vault files, "daily" for daily notes only
        style = "sidebar",
        focus = false,
      },
    })
  end,
  keys = {
    { "<leader>tt", "<cmd>Tnote<CR>",        desc = "tnote: toggle task list" },
    { "<leader>ts", "<cmd>TnoteSidebar<CR>",  desc = "tnote: toggle sidebar" },
    { "<leader>ta", "<cmd>TnoteAdd<CR>",      desc = "tnote: add task" },
  },
}
