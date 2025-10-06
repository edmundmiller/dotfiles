-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Language packs
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.nextflow" },

  -- Git integration
  { import = "astrocommunity.git.octo-nvim" },
  { import = "astrocommunity.git.neogit" },
  { import = "astrocommunity.git.git-blame-nvim" },
  { import = "astrocommunity.git.diffview-nvim" },

  -- Completion
  { import = "astrocommunity.completion.blink-cmp" },

  -- Comment
  { import = "astrocommunity.comment.mini-comment" },

  -- Note taking
  { import = "astrocommunity.note-taking.obsidian-nvim" },
  { import = "astrocommunity.note-taking.neorg" }, -- Org-mode alternative

  -- Testing
  { import = "astrocommunity.test.neotest" },

  -- Terminal integration
  { import = "astrocommunity.terminal-integration.toggleterm-manager-nvim" },

  -- Colorscheme
  { import = "astrocommunity.colorscheme.catppuccin" },
}
