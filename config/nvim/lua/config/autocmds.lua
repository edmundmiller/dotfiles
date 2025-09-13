-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Nextflow-specific settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "nextflow",
  callback = function(ev)
    vim.bo.commentstring = "// %s"
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.expandtab = true
    
    -- Force start treesitter highlighting
    vim.defer_fn(function()
      pcall(vim.treesitter.start, ev.buf, "nextflow")
    end, 50)
  end,
})

-- Force treesitter for todotxt files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "todotxt",
  callback = function(ev)
    vim.defer_fn(function()
      pcall(vim.treesitter.start, ev.buf, "todotxt")
    end, 50)
  end,
})

-- Enable text wrapping for prose formats
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "org", "typst", "text", "tex", "rst" },
  callback = function()
    -- Enable soft wrapping
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true -- Wrap at word boundaries
    vim.opt_local.textwidth = 0 -- Disable hard wrapping
    vim.opt_local.wrapmargin = 0
    
    -- Better navigation for wrapped lines
    vim.keymap.set("n", "j", "gj", { buffer = true, desc = "Move down through wrapped lines" })
    vim.keymap.set("n", "k", "gk", { buffer = true, desc = "Move up through wrapped lines" })
    vim.keymap.set("n", "0", "g0", { buffer = true, desc = "Move to beginning of wrapped line" })
    vim.keymap.set("n", "$", "g$", { buffer = true, desc = "Move to end of wrapped line" })
    
    -- Optional: Set conceallevel for better markdown rendering
    if vim.bo.filetype == "markdown" then
      vim.opt_local.conceallevel = 2
    end
  end,
})
