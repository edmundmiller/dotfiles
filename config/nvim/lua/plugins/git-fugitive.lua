-- Vim-fugitive as a stable git interface alternative
return {
  -- Fugitive: The premier Vim plugin for Git
  {
    "tpope/vim-fugitive",
    cmd = {
      "G",
      "Git",
      "Gdiffsplit",
      "Gread",
      "Gwrite",
      "Ggrep",
      "GMove",
      "GDelete",
      "GBrowse",
      "GRemove",
      "GRename",
      "Glgrep",
      "Gedit",
      "Gsplit",
      "Gvsplit",
      "Gtabedit",
      "Gpedit",
      "Gdrop",
    },
    keys = {
      { "<leader>gf", "<cmd>Git<cr>", desc = "Fugitive status" },
      { "<leader>gF", "<cmd>tab Git<cr>", desc = "Fugitive (full tab)" },
      { "<leader>gR", "<cmd>Git rebase -i<cr>", desc = "Git interactive rebase" },
    },
  },
}