-- Run from the repo root: nvim --clean --headless -l config/nvim/tests/review_tools_test.lua
-- Uses the installed Conform plugin, without loading Lazy or installing anything.
local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo .. '/config/nvim')
vim.opt.rtp:append(vim.fn.stdpath 'data' .. '/lazy/conform.nvim')
vim.g.mapleader = ' '

-- Isolate the OS clipboard, but exercise real mappings, buffers and registers.
local clipboard = {}
vim.g.clipboard = {
  name = 'review-tools-test',
  copy = { ['+'] = function(lines, kind) clipboard = { lines, kind } end },
  paste = { ['+'] = function() return clipboard end },
}
require 'keymaps'
local spec = require('kickstart.plugins.conform')[1]
spec.init()
for _, key in ipairs(spec.keys) do
  vim.keymap.set(key.mode or 'n', key[1], key[2])
end
-- A deterministic external formatter makes save-time behavior visible on disk.
spec.opts.formatters_by_ft.text = { 'test_uppercase' }
spec.opts.formatters_by_ft.c = { 'test_uppercase' }
spec.opts.formatters = { test_uppercase = { command = 'tr', args = { 'a-z', 'A-Z' }, stdin = true } }
require('conform').setup(spec.opts)

local function press(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'xt', false) end

local temp = vim.fn.tempname()
local ok, err = xpcall(function()
  vim.fn.mkdir(temp .. '/project/.git', 'p')
  vim.fn.mkdir(temp .. '/project/src', 'p')
  temp = assert(vim.uv.fs_realpath(temp)) -- macOS resolves /var through /private/var.
  vim.cmd.cd(temp .. '/project/src')
  vim.cmd.edit 'sample file.ts'
  vim.bo.filetype = 'typescript'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'outside', 'const value = 17;', '```', 'last selected', 'outside too' })
  press '3G yf'
  vim.fn.assert_equal('src/sample file.ts:3', vim.fn.getreg '+')
  press ' yp'
  vim.fn.assert_equal(temp .. '/project/src/sample file.ts:3', vim.fn.getreg '+')
  -- Reverse characterwise selection still copies complete lines and correct bounds.
  press '4Gvkk yf'
  vim.fn.assert_equal('src/sample file.ts:2-4', vim.fn.getreg '+')
  press '2GVjj yp'
  vim.fn.assert_equal(temp .. '/project/src/sample file.ts:2-4', vim.fn.getreg '+')
  press '4Gvkk cc'
  vim.fn.assert_equal('````ts filename="src/sample file.ts" line=2\nconst value = 17;\n```\nlast selected\n````', vim.fn.getreg '+')

  vim.cmd.enew { bang = true }
  vim.fn.setreg('+', 'keep clipboard')
  press ' yf'
  vim.fn.assert_equal('keep clipboard', vim.fn.getreg '+', 'Unnamed buffers must not replace the clipboard')
  vim.cmd.cd(temp)
  vim.cmd.edit 'plain.txt'
  press ' yf'
  vim.fn.assert_equal('plain.txt:1', vim.fn.getreg '+', 'Outside Git, references use cwd')

  vim.bo.filetype = 'text'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'first change' })
  press ' tf'
  vim.cmd.write()
  vim.fn.assert_equal({ 'first change' }, vim.fn.readfile(temp .. '/plain.txt'))
  local disabled_buffer = vim.api.nvim_get_current_buf()

  vim.cmd.edit 'other.txt'
  vim.bo.filetype = 'text'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'second change' })
  vim.cmd.write()
  vim.fn.assert_equal({ 'SECOND CHANGE' }, vim.fn.readfile(temp .. '/other.txt'), 'Toggle must not affect other buffers')

  vim.api.nvim_set_current_buf(disabled_buffer)
  press ' f'
  vim.fn.assert_true(vim.wait(2000, function() return vim.api.nvim_get_current_line() == 'FIRST CHANGE' end), 'Manual format still works')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'enabled again' })
  vim.cmd.ToggleFormatter()
  vim.cmd.write()
  vim.fn.assert_equal({ 'ENABLED AGAIN' }, vim.fn.readfile(temp .. '/plain.txt'))

  vim.bo.filetype = 'c'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'excluded language' })
  vim.cmd.write()
  vim.fn.assert_equal({ 'excluded language' }, vim.fn.readfile(temp .. '/plain.txt'), 'Existing C exclusion is preserved')
end, debug.traceback)
vim.cmd.cd(repo)
vim.fn.delete(temp, 'rf')
assert(ok, err)
assert(#vim.v.errors == 0, table.concat(vim.v.errors, '\n'))
print 'Review tools: clipboard mappings and buffer-local formatting passed'
