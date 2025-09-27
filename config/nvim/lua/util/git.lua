-- Git utility functions for interactive operations
local M = {}

-- Get the parent branch (dev > develop > main > master) - always prefer origin
function M.get_parent_branch()
  -- Try branches in priority order - ALWAYS prefer origin/remote branches
  local branches = { "dev", "develop", "main", "master" }

  -- First pass: check if remote branches exist locally
  for _, b in ipairs(branches) do
    local exists = vim.fn.system("git rev-parse --verify origin/" .. b .. " 2>/dev/null")
    if vim.v.shell_error == 0 then
      return "origin/" .. b
    end
  end

  -- If we didn't find dev/develop remotely, try fetching them specifically
  -- This is faster than fetching everything
  vim.fn.system("git fetch origin dev:refs/remotes/origin/dev 2>/dev/null")
  if vim.v.shell_error == 0 then
    return "origin/dev"
  end

  vim.fn.system("git fetch origin develop:refs/remotes/origin/develop 2>/dev/null")
  if vim.v.shell_error == 0 then
    return "origin/develop"
  end

  -- Fallback: try to detect default branch from origin/HEAD
  local default_branch = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@'"):gsub("%s+", "")
  if default_branch ~= "" then
    return default_branch
  end

  -- Last resort: check local branches
  for _, b in ipairs(branches) do
    local exists = vim.fn.system("git rev-parse --verify " .. b .. " 2>/dev/null")
    if vim.v.shell_error == 0 then
      return b
    end
  end

  return "origin/main" -- Default fallback
end

-- Get the default branch name (backward compatibility)
function M.get_default_branch_name()
  return M.get_parent_branch()
end

-- Interactive diff with menu selection
function M.open_diff_interactive()
  local default_branch = M.get_parent_branch()

  -- Find merge base for more accurate feature branch diff
  local merge_base = vim.fn.system("git merge-base HEAD " .. default_branch):gsub("%s+", "")
  local feature_branch_pattern = merge_base ~= "" and (merge_base .. "..HEAD") or (default_branch .. "..HEAD")
  local feature_branch_desc = merge_base ~= "" and "Your changes (from merge base)" or ("Feature branch changes from " .. default_branch)

  -- Use git-compatible options for both git and jj repos
  local options = {
    { "", "Working directory changes" },
    { "HEAD", "Last commit" },
    { "HEAD~3", "Last 3 commits" },
    { feature_branch_pattern, feature_branch_desc },
    { default_branch .. "..HEAD", "All changes from " .. default_branch .. " tip" },
    { "HEAD^!", "Only last commit (no context)" },
    { "@{u}..HEAD", "Unpushed changes" },
    { "@{1}", "Previous HEAD position" },
    { "stash", "View stashed changes" },
    { "--staged", "Only staged changes" },
    { "--cached", "Staged changes (cached)" },
    { "custom", "Enter custom revision..." },
  }

  -- Create menu items
  local menu_items = {}
  for _, opt in ipairs(options) do
    table.insert(menu_items, opt[1] .. " - " .. opt[2])
  end

  vim.ui.select(menu_items, {
    prompt = "Select diff pattern:",
    format_item = function(item) return item end,
  }, function(choice)
    if not choice then return end

    -- Extract the pattern from the choice
    local pattern = choice:match("^(.-)%s*%-")

    if pattern == "custom" then
      -- Fall back to manual input
      local input = vim.fn.input("Revision to diff (HEAD, HEAD~3, main..HEAD, stash): ")
      if input ~= "" then
        vim.cmd("DiffviewOpen " .. input)
      end
    elseif pattern == "" then
      -- Working directory changes
      vim.cmd("DiffviewOpen")
    else
      vim.cmd("DiffviewOpen " .. pattern)
    end
  end)
end

-- Interactive file history with menu selection
function M.file_history_interactive()
  local options = {
    { "%", "Current file" },
    { ".", "Entire repository" },
    { "% --follow", "Current file (follow renames)" },
    { "% --range=" .. vim.fn.line(".") .. ",+1", "Current line history" },
    { vim.fn.expand("%:h"), "Current directory" },
    { "src/", "src/ directory" },
    { "*.lua", "All Lua files" },
    { "*.py", "All Python files" },
    { "*.js *.ts *.jsx *.tsx", "All JavaScript/TypeScript files" },
    { "custom", "Enter custom path..." },
  }

  -- Create menu items
  local menu_items = {}
  for _, opt in ipairs(options) do
    table.insert(menu_items, opt[1] .. " - " .. opt[2])
  end

  vim.ui.select(menu_items, {
    prompt = "Select file history pattern:",
    format_item = function(item) return item end,
  }, function(choice)
    if not choice then return end

    -- Extract the pattern from the choice
    local pattern = choice:match("^(.-)%s*%-")

    if pattern == "custom" then
      -- Fall back to manual input
      local input = vim.fn.input("File history (. for all, % for current, or path): ", "%")
      if input ~= "" then
        vim.cmd("DiffviewFileHistory " .. input)
      end
    else
      vim.cmd("DiffviewFileHistory " .. pattern)
    end
  end)
end

-- Review PR changes
function M.review_pr_changes()
  local parent_branch = M.get_parent_branch()

  -- Find the merge base with the parent branch
  local merge_base = vim.fn.system("git merge-base HEAD " .. parent_branch):gsub("%s+", "")
  if vim.v.shell_error == 0 and merge_base ~= "" then
    vim.cmd("DiffviewOpen " .. merge_base .. "..HEAD")
  else
    vim.notify("Could not find merge base with " .. parent_branch, vim.log.levels.ERROR)
  end
end

-- Delete worktree with telescope picker
function M.delete_worktree()
  local worktree = require("git-worktree")
  local telescope = require("telescope")

  telescope.extensions.git_worktree.git_worktrees({
    attach_mappings = function(_, map_fn)
      map_fn("i", "<CR>", function(prompt_bufnr)
        local selection = require("telescope.actions.state").get_selected_entry()
        require("telescope.actions").close(prompt_bufnr)
        if selection then
          worktree.delete_worktree(selection.value)
        end
      end)
      map_fn("n", "<CR>", function(prompt_bufnr)
        local selection = require("telescope.actions.state").get_selected_entry()
        require("telescope.actions").close(prompt_bufnr)
        if selection then
          worktree.delete_worktree(selection.value)
        end
      end)
      return true
    end,
  })
end

-- Visual selection history
function M.visual_selection_history()
  -- Get visual selection range
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  -- Use line range for file history
  vim.cmd(string.format("DiffviewFileHistory %%:%d,%d", start_line, end_line))
end

-- Single line history using Gitsigns
function M.line_history()
  local ok, gitsigns = pcall(require, "gitsigns")
  if ok then
    gitsigns.blame_line({ full = true })
  else
    -- Fallback to DiffviewFileHistory for current line
    local line = vim.fn.line(".")
    vim.cmd(string.format("DiffviewFileHistory %%:%d,%d", line, line))
  end
end

-- Compare buffer/selection with clipboard
function M.compare_with_clipboard()
  local mode = vim.fn.mode()
  local clipboard = vim.fn.getreg("+")

  if clipboard == "" then
    vim.notify("Clipboard is empty", vim.log.levels.WARN)
    return
  end

  -- Create a temporary file with clipboard content
  local tmp_file = vim.fn.tempname()
  vim.fn.writefile(vim.split(clipboard, "\n"), tmp_file)

  if mode == "v" or mode == "V" then
    -- Visual mode: compare selection with clipboard
    -- Get visual selection
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    local lines = vim.fn.getline(start_line, end_line)

    -- Create temp file with selection
    local selection_file = vim.fn.tempname()
    vim.fn.writefile(lines, selection_file)

    -- Open diff view
    vim.cmd("tabnew")
    vim.cmd("edit " .. selection_file)
    vim.cmd("diffthis")
    vim.cmd("vsplit " .. tmp_file)
    vim.cmd("diffthis")
  else
    -- Normal mode: compare entire buffer with clipboard
    vim.cmd("tabnew %")
    vim.cmd("diffthis")
    vim.cmd("vsplit " .. tmp_file)
    vim.cmd("diffthis")
  end
end

-- Diff against parent branch (dev > develop > main > master)
function M.diff_against_default()
  local parent_branch = M.get_parent_branch()

  -- Find the merge base to show only our changes
  local merge_base = vim.fn.system("git merge-base HEAD " .. parent_branch):gsub("%s+", "")
  if vim.v.shell_error == 0 and merge_base ~= "" then
    -- Show changes from merge base to HEAD (just our changes)
    vim.cmd("DiffviewOpen " .. merge_base .. "..HEAD")
  else
    -- Fallback to showing diff against branch tip
    vim.cmd("DiffviewOpen " .. parent_branch)
  end
end

-- Show all repository history
function M.repo_history()
  vim.cmd("DiffviewFileHistory")
end

return M