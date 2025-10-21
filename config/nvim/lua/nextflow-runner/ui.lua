-- Nextflow Runner UI
-- Custom buffer UI for displaying workflow execution

local M = {}

local parser = require("nextflow-runner.parser")

-- UI state
M.bufnr = nil
M.winnr = nil
M.namespace = vim.api.nvim_create_namespace("nextflow_runner")

--- Create or get existing buffer
--- @return number Buffer number
function M.get_or_create_buffer()
  if M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) then
    return M.bufnr
  end

  M.bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(M.bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(M.bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(M.bufnr, "filetype", "nextflow-runner")
  vim.api.nvim_buf_set_name(M.bufnr, "Nextflow Runner")

  return M.bufnr
end

--- Show the runner buffer in a window
--- @return number Window number
function M.show()
  local bufnr = M.get_or_create_buffer()

  -- Check if buffer is already visible
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      M.winnr = win
      vim.api.nvim_set_current_win(win)
      return win
    end
  end

  -- Create new split window
  vim.cmd("botright vsplit")
  M.winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.winnr, bufnr)

  -- Set window options
  vim.api.nvim_win_set_option(M.winnr, "wrap", false)
  vim.api.nvim_win_set_option(M.winnr, "number", false)
  vim.api.nvim_win_set_option(M.winnr, "relativenumber", false)
  vim.api.nvim_win_set_option(M.winnr, "signcolumn", "no")

  return M.winnr
end

--- Hide the runner buffer
function M.hide()
  if M.winnr and vim.api.nvim_win_is_valid(M.winnr) then
    vim.api.nvim_win_close(M.winnr, true)
    M.winnr = nil
  end
end

--- Toggle buffer visibility
function M.toggle()
  if M.winnr and vim.api.nvim_win_is_valid(M.winnr) then
    M.hide()
  else
    M.show()
  end
end

--- Generate status icon for process
--- @param status string Process status
--- @return string Icon
local function get_status_icon(status)
  if status == "completed" then
    return "✓"
  elseif status == "running" then
    return "⟳"
  elseif status == "failed" then
    return "✗"
  else
    return "○"
  end
end

--- Generate progress bar
--- @param percentage number Percentage (0-100)
--- @param width number Width of progress bar
--- @return string Progress bar string
local function generate_progress_bar(percentage, width)
  width = width or 20
  local filled = math.floor((percentage / 100) * width)
  local empty = width - filled
  return "[" .. string.rep("█", filled) .. string.rep("░", empty) .. "]"
end

--- Format log level with color
--- @param level string Log level (INFO, WARN, ERROR)
--- @return string Formatted level
local function format_log_level(level)
  return "[" .. level .. "]"
end

--- Render workflow state to buffer
--- @param state table Workflow state from parser
function M.render(state)
  local bufnr = M.get_or_create_buffer()

  -- Clear existing content
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)

  local lines = {}
  local highlights = {}

  -- Helper to add line with optional highlight
  local function add_line(text, hl_group, hl_col_start, hl_col_end)
    table.insert(lines, text)
    if hl_group then
      table.insert(highlights, {
        line = #lines - 1,
        col_start = hl_col_start or 0,
        col_end = hl_col_end or #text,
        hl_group = hl_group,
      })
    end
  end

  -- Header
  add_line("╔════════════════════════════════════════════════╗")
  local header_text = "║ Nextflow Run: " .. (state.workflow or "unknown") .. string.rep(" ", 31 - #(state.workflow or "unknown")) .. "║"
  add_line(header_text)

  -- Status line
  local status_text = "Status: " .. (state.status or "unknown")
  local duration_text = state.duration or "00:00:00"
  local status_line = "║ " .. status_text .. string.rep(" ", 25 - #status_text) .. "| Time: " .. duration_text .. string.rep(" ", 9 - #duration_text) .. "║"
  add_line(status_line)

  -- Highlight status
  local status_hl = state.status == "completed" and "DiagnosticOk" or state.status == "failed" and "DiagnosticError" or "DiagnosticInfo"
  table.insert(highlights, {
    line = #lines - 1,
    col_start = 2,
    col_end = 2 + #status_text,
    hl_group = status_hl,
  })

  add_line("╠════════════════════════════════════════════════╣")

  -- Progress
  if state.progress.total > 0 then
    local progress_bar = generate_progress_bar(state.progress.percentage, 20)
    local progress_text = string.format("%s %d/%d (%d%%)", progress_bar, state.progress.completed, state.progress.total, state.progress.percentage)
    add_line("║ Progress: " .. progress_text .. string.rep(" ", 35 - #progress_text) .. "║")
  else
    add_line("║ Progress: Initializing..." .. string.rep(" ", 22) .. "║")
  end

  add_line("║" .. string.rep(" ", 48) .. "║")

  -- Process list
  local process_list = {}
  for name, process in pairs(state.processes) do
    table.insert(process_list, { name = name, data = process })
  end

  -- Sort by name
  table.sort(process_list, function(a, b)
    return a.name < b.name
  end)

  for _, item in ipairs(process_list) do
    local process = item.data
    local status = parser.get_process_status(process)
    local icon = get_status_icon(status)
    local process_text = string.format(
      "%s %s (%d/%d)",
      icon,
      process.name,
      process.completed,
      process.total
    )

    -- Pad to fit in box
    local padding = 46 - #process_text
    if padding < 0 then
      padding = 0
    end

    add_line("║ " .. process_text .. string.rep(" ", padding) .. "║")

    -- Highlight icon based on status
    local icon_hl = status == "completed" and "DiagnosticOk" or status == "running" and "DiagnosticWarn" or "Comment"
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 2,
      col_end = 4,
      hl_group = icon_hl,
    })
  end

  -- Empty line
  add_line("║" .. string.rep(" ", 48) .. "║")

  -- Summary
  if state.summary.succeeded > 0 or state.summary.failed > 0 then
    local summary_text = string.format(
      "✓ %d | ⚡ %d | ✗ %d",
      state.summary.succeeded,
      state.summary.cached,
      state.summary.failed
    )
    add_line("║ " .. summary_text .. string.rep(" ", 46 - #summary_text) .. "║")
  end

  -- Recent logs (last 5)
  if #state.logs > 0 then
    add_line("║" .. string.rep(" ", 48) .. "║")
    add_line("║ Recent logs:" .. string.rep(" ", 35) .. "║")

    local start_idx = math.max(1, #state.logs - 4)
    for i = start_idx, #state.logs do
      local log = state.logs[i]
      local level_text = format_log_level(log.level)
      local message = log.message

      -- Truncate message if too long
      local max_len = 46 - #level_text - 1
      if #message > max_len then
        message = message:sub(1, max_len - 3) .. "..."
      end

      local log_line = level_text .. " " .. message
      local padding = 46 - #log_line
      if padding < 0 then
        padding = 0
      end

      add_line("║ " .. log_line .. string.rep(" ", padding) .. "║")

      -- Highlight log level
      local level_hl = log.level == "ERROR" and "DiagnosticError" or log.level == "WARN" and "DiagnosticWarn" or "Comment"
      table.insert(highlights, {
        line = #lines - 1,
        col_start = 2,
        col_end = 2 + #level_text,
        hl_group = level_hl,
      })
    end
  end

  -- Footer with actions
  add_line("╠════════════════════════════════════════════════╣")
  add_line("║ Actions: [r]esume | [s]top | [l]ogs | [q]uit ║")
  add_line("╚════════════════════════════════════════════════╝")

  -- Set buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, M.namespace, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

--- Set up buffer keymaps
--- @param on_resume function Callback for resume action
--- @param on_stop function Callback for stop action
--- @param on_logs function Callback for logs action
--- @param on_quit function Callback for quit action
function M.setup_keymaps(on_resume, on_stop, on_logs, on_quit)
  local bufnr = M.get_or_create_buffer()

  local opts = { buffer = bufnr, silent = true, noremap = true }

  vim.keymap.set("n", "r", on_resume or function() end, opts)
  vim.keymap.set("n", "s", on_stop or function() end, opts)
  vim.keymap.set("n", "l", on_logs or function() end, opts)
  vim.keymap.set("n", "q", on_quit or function() end, opts)
end

--- Auto-scroll to bottom if enabled
--- @param enabled boolean Whether to auto-scroll
function M.auto_scroll(enabled)
  if not enabled or not M.winnr or not vim.api.nvim_win_is_valid(M.winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(M.winnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  vim.api.nvim_win_set_cursor(M.winnr, { line_count, 0 })
end

--- Clear buffer content
function M.clear()
  local bufnr = M.get_or_create_buffer()

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

return M
