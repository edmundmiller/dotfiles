-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Doom Emacs-style options

local opt = vim.opt

-- Leader key configuration (already set by LazyVim but ensuring consistency)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Doom Emacs-like behavior
opt.relativenumber = true -- Show relative line numbers like Doom
opt.wrap = false -- Don't wrap lines by default
opt.scrolloff = 8 -- Keep 8 lines above/below cursor
opt.sidescrolloff = 8 -- Keep 8 columns left/right of cursor
opt.signcolumn = "yes" -- Always show sign column
opt.colorcolumn = "80" -- Show column at 80 characters

-- Search behavior like Doom
opt.ignorecase = true -- Ignore case in search
opt.smartcase = true -- Override ignorecase if search contains uppercase
opt.inccommand = "split" -- Show substitution preview in split

-- Clipboard integration
opt.clipboard = "unnamedplus" -- Use system clipboard

-- Better completion
opt.completeopt = "menu,menuone,noselect"

-- Doom Emacs-style indentation
opt.expandtab = true -- Use spaces instead of tabs
opt.shiftwidth = 2 -- Size of indent
opt.tabstop = 2 -- Number of spaces tabs count for
opt.softtabstop = 2 -- Number of spaces tabs count for in insert mode

-- File handling
opt.backup = false -- Don't create backup files
opt.writebackup = false -- Don't create backup before overwriting
opt.swapfile = false -- Don't create swap files
opt.undofile = true -- Save undo history

-- Appearance
opt.termguicolors = true -- Enable 24-bit RGB colors
opt.pumheight = 10 -- Maximum number of items in popup menu
opt.cmdheight = 1 -- Command line height
opt.showmode = false -- Don't show mode in command line (shown in statusline)

-- Timing
opt.updatetime = 250 -- Faster completion (4000ms default)
opt.timeoutlen = 300 -- Time to wait for mapped sequence (like which-key delay)

-- Window behavior
opt.splitbelow = true -- Split below current window
opt.splitright = true -- Split to the right of current window

-- Mouse and trackpad behavior
opt.mouse = "a" -- Enable mouse support
opt.mousescroll = "ver:3,hor:0" -- Reduce horizontal scroll sensitivity (0 = disable)

-- Folding (for nvim-ufo)
opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- Doom Emacs-like variables
vim.g.autoformat = true -- Enable auto-formatting (can be toggled with SPC t f)

-- Use snacks picker as the default picker (faster than telescope)
vim.g.lazyvim_picker = "snacks"

-- Disable some built-in plugins that Doom doesn't use
vim.g.loaded_gzip = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1
