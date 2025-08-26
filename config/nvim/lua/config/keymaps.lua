-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Doom Emacs-style keymaps

local map = vim.keymap.set
local LazyVim = require("lazyvim.util")

-- File operations (Doom: SPC f ...)
map("n", "<leader>.", function() LazyVim.pick("files")() end, { desc = "Browse files" })
map("n", "<leader>ff", function() LazyVim.pick("files")() end, { desc = "Find file" })
map("n", "<leader>fr", function() LazyVim.pick("oldfiles")() end, { desc = "Recent files" })
map("n", "<leader>fR", function() LazyVim.pick("oldfiles", { cwd = vim.uv.cwd() })() end, { desc = "Recent files (project)" })
map("n", "<leader>fy", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
  vim.notify("Yanked: " .. vim.fn.expand("%:p"))
end, { desc = "Yank filename" })
map("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>fS", "<cmd>wa<cr>", { desc = "Save all files" })
map("n", "<leader>f/", function() LazyVim.pick("files")() end, { desc = "Find file in project" })

-- Quit operations (Doom: SPC q ...)
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>qQ", "<cmd>qa!<cr>", { desc = "Quit all (force)" })

-- Buffer operations (Doom: SPC b ...)
map("n", "<leader>,", function() LazyVim.pick("buffers")() end, { desc = "Switch buffer" })
map("n", "<leader>bb", function() LazyVim.pick("buffers")() end, { desc = "Switch buffer" })
map("n", "<leader>bB", function() LazyVim.pick("buffers")() end, { desc = "Switch to any buffer" })
map("n", "<leader>bk", "<cmd>bd<cr>", { desc = "Kill buffer" })
map("n", "<leader>bK", "<cmd>%bd|e#<cr>", { desc = "Kill other buffers" })
map("n", "<leader>bn", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<leader>bs", "<cmd>w<cr>", { desc = "Save buffer" })
map("n", "<leader>bS", "<cmd>wa<cr>", { desc = "Save all buffers" })
map("n", "<leader>bX", "<cmd>enew<cr>", { desc = "New scratch buffer" })

-- Window management (Doom: SPC w ...)
map("n", "<leader>wv", "<cmd>vsplit<cr>", { desc = "Split window vertically" })
map("n", "<leader>ws", "<cmd>split<cr>", { desc = "Split window horizontally" })
map("n", "<leader>ww", "<C-w>w", { desc = "Switch windows" })
map("n", "<leader>wh", "<C-w>h", { desc = "Window left" })
map("n", "<leader>wj", "<C-w>j", { desc = "Window down" })
map("n", "<leader>wk", "<C-w>k", { desc = "Window up" })
map("n", "<leader>wl", "<C-w>l", { desc = "Window right" })
map("n", "<leader>wc", "<C-w>c", { desc = "Close window" })
map("n", "<leader>wo", "<C-w>o", { desc = "Close other windows" })
map("n", "<leader>w=", "<C-w>=", { desc = "Balance windows" })
map("n", "<leader>wr", "<C-w>r", { desc = "Rotate windows" })
map("n", "<leader>wm", "<cmd>only<cr>", { desc = "Maximize window" })

-- Search operations (Doom: SPC s ...)
map("n", "<leader>ss", function() LazyVim.pick("lines")() end, { desc = "Search buffer" })
map("n", "<leader>sp", function() LazyVim.pick("live_grep")() end, { desc = "Search project" })
map("n", "<leader>sd", function() LazyVim.pick("live_grep", { cwd = "." })() end, { desc = "Search directory" })
map("n", "<leader>si", function() LazyVim.pick("lsp_workspace_symbols")() end, { desc = "Search symbols" })
map("n", "<leader>/", function() LazyVim.pick("live_grep")() end, { desc = "Search project" })
map("n", "<leader>sr", "<cmd>lua require('spectre').toggle()<cr>", { desc = "Search & Replace" })

-- Project operations (Doom: SPC p ...)
map("n", "<leader>pp", "<cmd>Telescope projects<cr>", { desc = "Switch project" })
map("n", "<leader>pf", function() LazyVim.pick("files")() end, { desc = "Find file in project" })
map("n", "<leader>pr", function() LazyVim.pick("oldfiles", { cwd = vim.uv.cwd() })() end, { desc = "Recent project files" })
map("n", "<leader>p.", "<cmd>Oil<cr>", { desc = "Browse project" })
map("n", "<leader>pd", "<cmd>Telescope file_browser<cr>", { desc = "Find directory" })
map("n", "<leader>pD", "<cmd>Oil<cr>", { desc = "Open project root" })
map("n", "<leader>p/", function() LazyVim.pick("live_grep")() end, { desc = "Search in project" })

-- Git operations (Doom: SPC g ...)
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>gf", "<cmd>Git<cr>", { desc = "Fugitive (stable git interface)" })
map("n", "<leader>gt", function() LazyVim.pick("git_status")() end, { desc = "Git status (Telescope)" })
-- Neogit with workaround for difftastic conflict
map("n", "<leader>gn", function()
  -- Temporarily disable difftastic to prevent SIGSEGV
  local old_git_external_diff = vim.env.GIT_EXTERNAL_DIFF
  vim.env.GIT_EXTERNAL_DIFF = ""
  
  local ok, err = pcall(function() 
    vim.cmd("Neogit")
  end)
  
  -- Restore original setting after Neogit opens
  vim.defer_fn(function()
    vim.env.GIT_EXTERNAL_DIFF = old_git_external_diff
  end, 100)
  
  if not ok then
    vim.notify("Neogit crashed. Try <leader>gg for LazyGit instead", vim.log.levels.ERROR)
  end
end, { desc = "Neogit (Magit-like)" })
map("n", "<leader>gs", function() LazyVim.pick("git_status")() end, { desc = "Git status" })
map("n", "<leader>gb", function() LazyVim.pick("git_branches")() end, { desc = "Git branches" })
map("n", "<leader>gl", function() LazyVim.pick("git_commits")() end, { desc = "Git log" })
map("n", "<leader>gL", function() LazyVim.pick("git_bcommits")() end, { desc = "Git log (buffer)" })
map("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Git diff" })
map("n", "<leader>gD", "<cmd>DiffviewOpen<cr>", { desc = "Diffview open" })
map("n", "<leader>gv", "<cmd>DiffviewOpen<cr>", { desc = "View diff" })
map("n", "<leader>gV", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "Full history" })
map("n", "<leader>gC", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" })
map("n", "<leader>gB", "<cmd>Gitsigns blame_line<cr>", { desc = "Git blame line" })
-- Git hunk operations (moved to gh prefix to avoid conflict with Octo)
map("n", "<leader>ghr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
map("n", "<leader>ghR", "<cmd>Gitsigns reset_buffer<cr>", { desc = "Reset buffer" })
map("n", "<leader>ghp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
map("n", "<leader>ghS", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
map("n", "<leader>ghu", "<cmd>Gitsigns undo_stage_hunk<cr>", { desc = "Undo stage hunk" })

-- GitHub operations via Octo (LazyVim extra provides these automatically):
-- <leader>gi - List Issues
-- <leader>gI - Search Issues  
-- <leader>gp - List PRs
-- <leader>gP - Search PRs
-- <leader>gr - List Repos
-- <leader>gS - General Search

-- Code operations (Doom: SPC c ...)
map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer" })
map("n", "<leader>cc", "<cmd>Make<cr>", { desc = "Compile" })
map("n", "<leader>cC", "<cmd>Make!<cr>", { desc = "Recompile" })

-- Toggle operations (Doom: SPC t ...)
map("n", "<leader>tl", "<cmd>set nu!<cr>", { desc = "Toggle line numbers" })
map("n", "<leader>tw", "<cmd>set wrap!<cr>", { desc = "Toggle word wrap" })
map("n", "<leader>tf", "<cmd>set fullscreen!<cr>", { desc = "Toggle fullscreen" })

-- Help operations (Doom: SPC h ...)
map("n", "<leader>hv", function() LazyVim.pick("help_tags")() end, { desc = "Describe variable" })
map("n", "<leader>hf", function() LazyVim.pick("help_tags")() end, { desc = "Describe function" })
map("n", "<leader>hk", function() LazyVim.pick("keymaps")() end, { desc = "Describe keybinding" })
map("n", "<leader>hm", function() LazyVim.pick("man_pages")() end, { desc = "Man pages" })

-- Quick access (Doom shortcuts)
map("n", "<leader><space>", function() LazyVim.pick("files")() end, { desc = "Find file (quick)" })
map("n", "<leader>:", function() LazyVim.pick("commands")() end, { desc = "Execute command" })

-- Navigation (Evil-style but enhanced)
map("n", "gd", function() LazyVim.pick("lsp_definitions")() end, { desc = "Go to definition" })
map("n", "gD", function() LazyVim.pick("lsp_references")() end, { desc = "Go to references" })
map("n", "gi", function() LazyVim.pick("lsp_implementations")() end, { desc = "Go to implementation" })
map("n", "gt", function() LazyVim.pick("lsp_type_definitions")() end, { desc = "Go to type definition" })

-- Notes operations (Doom: SPC n ...)
-- Obsidian keybindings are now in lua/plugins/obsidian.lua with Doom-style <leader>nn prefix

-- Org-roam operations (using <leader>oR prefix to avoid conflicts with obsidian)
map("n", "<leader>oRf", "<cmd>lua require('org-roam').api.find_node()<cr>", { desc = "Org-roam: Find node" })
map("n", "<leader>oRi", "<cmd>lua require('org-roam').api.insert_node()<cr>", { desc = "Org-roam: Insert node" })
map("n", "<leader>oRc", "<cmd>lua require('org-roam').api.capture_node()<cr>", { desc = "Org-roam: Capture node" })
map("n", "<leader>oRb", "<cmd>lua require('org-roam').ui.toggle_roam_buffer()<cr>", { desc = "Org-roam: Toggle buffer" })
map("n", "<leader>oRd", "<cmd>lua require('org-roam').ext.dailies.goto_today()<cr>", { desc = "Org-roam: Today's daily" })
map("n", "<leader>oRD", "<cmd>lua require('org-roam').ext.dailies.capture_today()<cr>", { desc = "Org-roam: Capture today" })
map("n", "<leader>oRa", "<cmd>lua require('org-roam').api.add_alias()<cr>", { desc = "Org-roam: Add alias" })
map("n", "<leader>oRA", "<cmd>lua require('org-roam').api.remove_alias()<cr>", { desc = "Org-roam: Remove alias" })

-- Org mode operations (Doom: SPC o ...)
-- Global org commands are handled by the orgmode plugin itself
-- Only define the most essential ones here for consistency

-- Org mode specific buffer operations
vim.api.nvim_create_autocmd("FileType", {
  pattern = "org",
  callback = function()
    -- Essential org-mode operations for the current buffer
    -- Most keybindings are handled by the orgmode plugin itself
    -- These are supplementary bindings following Doom Emacs convention
    
    -- TODO management
    map("n", "<leader>mt", "<cmd>lua require('orgmode').action('org_mappings.org_todo')<cr>", { desc = "Toggle TODO", buffer = true })
    map("n", "<leader>mT", "<cmd>lua require('orgmode').action('org_mappings.org_todo_prev')<cr>", { desc = "Previous TODO", buffer = true })
    
    -- Scheduling and deadlines
    map("n", "<leader>md", "<cmd>lua require('orgmode').action('org_mappings.org_deadline')<cr>", { desc = "Set deadline", buffer = true })
    map("n", "<leader>ms", "<cmd>lua require('orgmode').action('org_mappings.org_schedule')<cr>", { desc = "Set schedule", buffer = true })
    
    -- Archiving
    map("n", "<leader>ma", "<cmd>lua require('orgmode').action('org_mappings.org_archive_subtree')<cr>", { desc = "Archive subtree", buffer = true })
    
    -- Export
    map("n", "<leader>me", "<cmd>lua require('orgmode').action('org_mappings.org_export')<cr>", { desc = "Export", buffer = true })
    
    -- Table operations (if vim-table-mode is installed)
    if vim.fn.exists(":TableModeToggle") == 2 then
      map("n", "<leader>mtt", "<cmd>TableModeToggle<cr>", { desc = "Toggle table mode", buffer = true })
      map("n", "<leader>mtr", "<cmd>TableModeRealign<cr>", { desc = "Realign table", buffer = true })
    end
  end,
})
