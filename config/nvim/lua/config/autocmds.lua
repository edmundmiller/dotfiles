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
