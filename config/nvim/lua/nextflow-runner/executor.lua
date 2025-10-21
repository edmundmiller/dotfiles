-- Nextflow executor
-- Handles async execution of Nextflow workflows

local M = {}

local parser = require("nextflow-runner.parser")

--- Find the project root directory
--- @param start_path string Starting path (usually current file)
--- @return string|nil Root directory or nil if not found
function M.find_root(start_path)
  local path = start_path or vim.fn.expand("%:p:h")

  -- Look for Nextflow project markers
  local markers = { "nextflow.config", "main.nf", ".git" }

  local function search_up(dir)
    for _, marker in ipairs(markers) do
      local marker_path = dir .. "/" .. marker
      if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
        return dir
      end
    end

    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end
    return search_up(parent)
  end

  return search_up(path)
end

--- Build Nextflow command
--- @param workflow_file string Path to workflow file
--- @param opts table Options (resume, args, etc.)
--- @return table Command array
function M.build_command(workflow_file, opts)
  opts = opts or {}

  local cmd = { "nextflow", "run", workflow_file }

  -- Add resume flag
  if opts.resume then
    table.insert(cmd, "-resume")
  end

  -- Add custom arguments
  if opts.args then
    if type(opts.args) == "string" then
      -- Split string args
      for arg in opts.args:gmatch("%S+") do
        table.insert(cmd, arg)
      end
    elseif type(opts.args) == "table" then
      vim.list_extend(cmd, opts.args)
    end
  end

  -- Add ANSI log flag for colored output
  table.insert(cmd, "-ansi-log")
  table.insert(cmd, "false")

  return cmd
end

--- Execute Nextflow workflow
--- @param workflow_file string Path to workflow file
--- @param opts table Options
--- @param on_output function Callback for output lines
--- @param on_exit function Callback when execution completes
--- @return table|nil Job handle or nil on error
function M.execute(workflow_file, opts, on_output, on_exit)
  opts = opts or {}

  -- Find project root
  local root = M.find_root(workflow_file)
  if not root then
    vim.notify("Could not find Nextflow project root", vim.log.levels.ERROR)
    return nil
  end

  -- Build command
  local cmd = M.build_command(workflow_file, opts)

  -- Output buffer for accumulating lines
  local output_lines = {}
  local partial_line = ""

  -- Create job
  local job_id = vim.fn.jobstart(cmd, {
    cwd = root,
    on_stdout = function(_, data, _)
      if not data then
        return
      end

      -- Process each line
      for i, line in ipairs(data) do
        if i == 1 then
          -- Prepend any partial line from previous chunk
          line = partial_line .. line
          partial_line = ""
        end

        if i == #data then
          -- Last item might be partial line
          if line == "" then
            -- Complete line ending
            if #output_lines > 0 or partial_line ~= "" then
              table.insert(output_lines, partial_line)
              if on_output then
                on_output(partial_line, output_lines)
              end
              partial_line = ""
            end
          else
            -- Incomplete line, save for next chunk
            partial_line = line
          end
        else
          -- Complete line
          table.insert(output_lines, line)
          if on_output then
            on_output(line, output_lines)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if not data then
        return
      end

      -- Process stderr the same way as stdout
      for i, line in ipairs(data) do
        if i == 1 then
          line = partial_line .. line
          partial_line = ""
        end

        if i == #data then
          if line == "" then
            if #output_lines > 0 or partial_line ~= "" then
              table.insert(output_lines, partial_line)
              if on_output then
                on_output(partial_line, output_lines)
              end
              partial_line = ""
            end
          else
            partial_line = line
          end
        else
          table.insert(output_lines, line)
          if on_output then
            on_output(line, output_lines)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      -- Process any remaining partial line
      if partial_line ~= "" then
        table.insert(output_lines, partial_line)
        if on_output then
          on_output(partial_line, output_lines)
        end
      end

      if on_exit then
        on_exit(exit_code, output_lines)
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start Nextflow job", vim.log.levels.ERROR)
    return nil
  end

  return {
    job_id = job_id,
    workflow_file = workflow_file,
    root = root,
    command = cmd,
    output_lines = output_lines,
  }
end

--- Stop a running Nextflow job
--- @param job table Job handle from execute()
function M.stop(job)
  if job and job.job_id then
    vim.fn.jobstop(job.job_id)
  end
end

--- Check if a job is running
--- @param job table Job handle from execute()
--- @return boolean True if job is still running
function M.is_running(job)
  if not job or not job.job_id then
    return false
  end

  local status = vim.fn.jobwait({ job.job_id }, 0)[1]
  return status == -1 -- -1 means still running
end

--- Get the last session ID from .nextflow.log
--- @param root string Project root directory
--- @return string|nil Session ID or nil
function M.get_last_session(root)
  local log_file = root .. "/.nextflow.log"

  if vim.fn.filereadable(log_file) == 0 then
    return nil
  end

  -- Read last few lines of log file
  local lines = vim.fn.readfile(log_file, "", 50)

  -- Search backwards for session ID
  for i = #lines, 1, -1 do
    local session_id = lines[i]:match("%[([%w_%-]+)%]")
    if session_id then
      return session_id
    end
  end

  return nil
end

--- Check if nextflow is available
--- @return boolean True if nextflow command is available
function M.check_nextflow()
  local handle = io.popen("which nextflow 2>/dev/null")
  if not handle then
    return false
  end

  local result = handle:read("*a")
  handle:close()

  return result ~= ""
end

return M
