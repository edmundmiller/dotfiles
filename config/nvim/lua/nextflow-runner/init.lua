-- Nextflow Runner
-- Main module for Nextflow workflow execution with custom UI

local M = {}

local executor = require("nextflow-runner.executor")
local parser = require("nextflow-runner.parser")
local ui = require("nextflow-runner.ui")

-- Module state
M.config = {
  auto_scroll = true,
  refresh_rate = 500, -- milliseconds
  default_args = {},
  log_level = "info",
  auto_show = true, -- Automatically show UI when running
}

M.current_job = nil
M.current_state = nil
M.timer = nil

--- Setup the module with configuration
--- @param opts table|nil Configuration options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Check if nextflow is available
  if not executor.check_nextflow() then
    vim.notify("Nextflow command not found. Please install Nextflow.", vim.log.levels.WARN)
  end
end

--- Update UI with current state
local function update_ui()
  if M.current_state then
    ui.render(M.current_state)
    ui.auto_scroll(M.config.auto_scroll)
  end
end

--- Start refresh timer
local function start_refresh_timer()
  if M.timer then
    return
  end

  M.timer = vim.loop.new_timer()
  M.timer:start(
    M.config.refresh_rate,
    M.config.refresh_rate,
    vim.schedule_wrap(function()
      update_ui()
    end)
  )
end

--- Stop refresh timer
local function stop_refresh_timer()
  if M.timer then
    M.timer:stop()
    M.timer:close()
    M.timer = nil
  end
end

--- Handle output from Nextflow execution
--- @param line string Output line
--- @param all_lines table All output lines so far
local function handle_output(line, all_lines)
  -- Parse output and update state
  M.current_state = parser.parse_output(all_lines)

  -- Log important messages
  local parsed = parser.parse_line(line)
  if parsed and parsed.type == "log" and M.config.log_level ~= "silent" then
    if parsed.level == "ERROR" then
      vim.notify(parsed.message, vim.log.levels.ERROR)
    elseif parsed.level == "WARN" and M.config.log_level == "debug" then
      vim.notify(parsed.message, vim.log.levels.WARN)
    end
  end
end

--- Handle workflow completion
--- @param exit_code number Exit code from Nextflow
--- @param output_lines table All output lines
local function handle_exit(exit_code, output_lines)
  stop_refresh_timer()

  -- Final state update
  M.current_state = parser.parse_output(output_lines)

  -- Update status based on exit code
  if exit_code == 0 then
    M.current_state.status = "completed"
    vim.notify("Workflow completed successfully!", vim.log.levels.INFO)
  else
    M.current_state.status = "failed"
    vim.notify("Workflow failed with exit code " .. exit_code, vim.log.levels.ERROR)
  end

  -- Final UI update
  update_ui()

  M.current_job = nil
end

--- Run a Nextflow workflow
--- @param opts table|nil Options (workflow, resume, args)
function M.run(opts)
  opts = opts or {}

  -- Check if already running
  if M.current_job and executor.is_running(M.current_job) then
    vim.notify("A workflow is already running. Stop it first or wait for completion.", vim.log.levels.WARN)
    return
  end

  -- Determine workflow file
  local workflow_file = opts.workflow
  if not workflow_file then
    -- Use current file if it's a .nf file
    local current_file = vim.fn.expand("%:p")
    if vim.fn.filereadable(current_file) == 1 and vim.endswith(current_file, ".nf") then
      workflow_file = current_file
    else
      -- Look for main.nf in project root
      local root = executor.find_root()
      if root then
        workflow_file = root .. "/main.nf"
      end
    end
  end

  if not workflow_file or vim.fn.filereadable(workflow_file) == 0 then
    vim.notify("Could not find workflow file to run", vim.log.levels.ERROR)
    return
  end

  -- Merge default args with provided args
  local run_opts = {
    resume = opts.resume or false,
    args = opts.args or M.config.default_args,
  }

  -- Initialize state
  M.current_state = {
    status = "starting",
    workflow = vim.fn.fnamemodify(workflow_file, ":t"),
    processes = {},
    progress = { completed = 0, total = 0, percentage = 0 },
    summary = { succeeded = 0, cached = 0, failed = 0 },
    logs = {},
  }

  -- Show UI if configured
  if M.config.auto_show then
    ui.show()
  end

  -- Setup keymaps
  ui.setup_keymaps(
    function()
      M.resume()
    end,
    function()
      M.stop()
    end,
    function()
      M.show_logs()
    end,
    function()
      ui.hide()
    end
  )

  -- Initial render
  update_ui()

  -- Start execution
  vim.notify("Starting workflow: " .. workflow_file, vim.log.levels.INFO)
  M.current_job = executor.execute(workflow_file, run_opts, handle_output, handle_exit)

  if not M.current_job then
    vim.notify("Failed to start workflow execution", vim.log.levels.ERROR)
    return
  end

  -- Start refresh timer
  start_refresh_timer()
end

--- Resume the last workflow
function M.resume()
  if M.current_job and executor.is_running(M.current_job) then
    vim.notify("Workflow is already running", vim.log.levels.WARN)
    return
  end

  -- Get workflow file from current state or buffer
  local workflow_file
  if M.current_job then
    workflow_file = M.current_job.workflow_file
  else
    workflow_file = vim.fn.expand("%:p")
    if not vim.endswith(workflow_file, ".nf") then
      local root = executor.find_root()
      if root then
        workflow_file = root .. "/main.nf"
      end
    end
  end

  M.run({ workflow = workflow_file, resume = true })
end

--- Stop the current workflow
function M.stop()
  if not M.current_job then
    vim.notify("No workflow is running", vim.log.levels.WARN)
    return
  end

  if not executor.is_running(M.current_job) then
    vim.notify("Workflow is not running", vim.log.levels.WARN)
    return
  end

  executor.stop(M.current_job)
  stop_refresh_timer()

  if M.current_state then
    M.current_state.status = "stopped"
  end

  update_ui()
  vim.notify("Workflow stopped", vim.log.levels.INFO)
end

--- Show the runner UI
function M.show()
  ui.show()

  if M.current_state then
    update_ui()
  else
    ui.clear()
    vim.notify("No workflow has been run yet", vim.log.levels.INFO)
  end
end

--- Hide the runner UI
function M.hide()
  ui.hide()
end

--- Toggle UI visibility
function M.toggle()
  ui.toggle()
  if M.current_state then
    update_ui()
  end
end

--- Show full workflow logs
function M.show_logs()
  if not M.current_job then
    vim.notify("No workflow logs available", vim.log.levels.WARN)
    return
  end

  local root = M.current_job.root
  local log_file = root .. "/.nextflow.log"

  if vim.fn.filereadable(log_file) == 0 then
    vim.notify("Log file not found: " .. log_file, vim.log.levels.ERROR)
    return
  end

  -- Open log file in new split
  vim.cmd("botright split " .. vim.fn.fnameescape(log_file))
  vim.cmd("normal! G") -- Jump to end
end

--- Get current workflow status
--- @return table|nil Current workflow state
function M.get_status()
  return M.current_state
end

--- Check if a workflow is currently running
--- @return boolean True if running
function M.is_running()
  return M.current_job ~= nil and executor.is_running(M.current_job)
end

--- Show DAG visualization (placeholder for future implementation)
function M.show_dag()
  vim.notify("DAG visualization not yet implemented. Coming soon!", vim.log.levels.INFO)
  -- Future: Could integrate with `nextflow view` or generate SVG/HTML
end

-- Cleanup on VimLeave
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if M.current_job and executor.is_running(M.current_job) then
      executor.stop(M.current_job)
    end
    stop_refresh_timer()
  end,
})

return M
