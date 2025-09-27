-- Git utility functions for interactive operations
local M = {}

-- Interactive diff with menu selection
function M.open_diff_interactive()
  -- Check if in jj repo to provide appropriate prompt
  local jj_root = vim.fn.system("jj root 2>/dev/null"):gsub("%s+", "")
  local is_jj = vim.v.shell_error == 0 and jj_root ~= ""

  local options = is_jj and {
    { "@-..@", "Changes from parent to current" },
    { "@--..@", "Changes from grandparent to current" },
    { "main@origin..@", "All changes from remote main" },
    { "@-", "Show parent change" },
    { "@", "Show current change" },
    { "custom", "Enter custom revision..." },
  } or {
    { "HEAD", "Last commit" },
    { "HEAD~3", "Last 3 commits" },
    { "main..HEAD", "Feature branch changes" },
    { "origin/main..HEAD", "Changes from remote main" },
    { "HEAD^!", "Only last commit (no context)" },
    { "@{u}..HEAD", "Unpushed changes" },
    { "@{1}", "Previous HEAD position" },
    { "stash", "View stashed changes" },
    { "--staged", "Only staged changes" },
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
      local prompt = is_jj
        and "Revision to diff (@, @-, @-..@, main..@): "
        or "Revision to diff (HEAD, HEAD~3, main..HEAD, stash): "

      local input = vim.fn.input(prompt)
      if input ~= "" then
        vim.cmd("DiffviewOpen " .. input)
      end
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
    { "src/", "src/ directory" },
    { "*.lua", "All Lua files" },
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
  -- Check if in jj repo
  local jj_root = vim.fn.system("jj root 2>/dev/null"):gsub("%s+", "")
  local is_jj = vim.v.shell_error == 0 and jj_root ~= ""

  if is_jj then
    -- For jj, show diff from main branch to current change
    local main_commit = vim.fn.system("jj log --no-graph -r 'main' -T 'commit_id' --limit 1 2>/dev/null"):gsub("%s+", "")

    if vim.v.shell_error == 0 and main_commit ~= "" then
      vim.cmd("DiffviewOpen " .. main_commit .. "..HEAD")
    else
      -- Fallback: try main@origin
      main_commit = vim.fn.system("jj log --no-graph -r 'main@origin' -T 'commit_id' --limit 1 2>/dev/null"):gsub("%s+", "")
      if vim.v.shell_error == 0 and main_commit ~= "" then
        vim.cmd("DiffviewOpen " .. main_commit .. "..HEAD")
      else
        -- Final fallback: show diff from parent to current
        vim.cmd("DiffviewOpen HEAD~..HEAD")
      end
    end
  else
    -- For git, find the merge base with main/master
    local main_branch = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'"):gsub("%s+", "")
    if main_branch == "" then
      main_branch = "main"
      -- Try master if main doesn't exist
      local branch_exists = vim.fn.system("git rev-parse --verify " .. main_branch .. " 2>/dev/null")
      if vim.v.shell_error ~= 0 then
        main_branch = "master"
      end
    end

    local merge_base = vim.fn.system("git merge-base HEAD " .. main_branch):gsub("%s+", "")
    if vim.v.shell_error == 0 and merge_base ~= "" then
      vim.cmd("DiffviewOpen " .. merge_base .. "..HEAD")
    else
      vim.notify("Could not find merge base with " .. main_branch, vim.log.levels.ERROR)
    end
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

return M