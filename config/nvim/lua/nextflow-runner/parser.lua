-- Nextflow output parser
-- Parses Nextflow workflow execution output for display in custom UI

local M = {}

--- Parse a single line of Nextflow output
--- @param line string
--- @return table|nil Parsed information or nil if not a recognized pattern
function M.parse_line(line)
  -- Remove ANSI color codes
  local clean_line = line:gsub("\27%[[%d;]*m", "")

  -- Parse executor info line: "executor >  local (8)"
  local executor_type, executor_count = clean_line:match("executor%s*>%s*(%w+)%s*%((%d+)%)")
  if executor_type then
    return {
      type = "executor",
      executor = executor_type,
      count = tonumber(executor_count),
    }
  end

  -- Parse progress line: "[42/50] process > PROCESS_NAME (sample_1)"
  local completed, total, process_name, sample = clean_line:match("%[(%d+)/(%d+)%]%s*process%s*>%s*([%w_]+)%s*%(([^)]+)%)")
  if completed and total then
    return {
      type = "progress",
      completed = tonumber(completed),
      total = tonumber(total),
      process = process_name,
      sample = sample,
      percentage = (tonumber(completed) / tonumber(total)) * 100,
    }
  end

  -- Parse simple progress line without sample: "[42/50] process > PROCESS_NAME"
  completed, total, process_name = clean_line:match("%[(%d+)/(%d+)%]%s*process%s*>%s*([%w_]+)")
  if completed and total then
    return {
      type = "progress",
      completed = tonumber(completed),
      total = tonumber(total),
      process = process_name,
      percentage = (tonumber(completed) / tonumber(total)) * 100,
    }
  end

  -- Parse workflow status: "Workflow completed"
  if clean_line:match("Workflow%s+completed") then
    return {
      type = "status",
      status = "completed",
    }
  end

  -- Parse workflow error: "Workflow failed"
  if clean_line:match("Workflow%s+failed") or clean_line:match("ERROR") then
    return {
      type = "status",
      status = "failed",
    }
  end

  -- Parse session ID: "Launching `main.nf` [session_id] - revision: abc123"
  local workflow_file, session_id = clean_line:match("Launching%s+`([^`]+)`%s+%[([^%]]+)%]")
  if session_id then
    return {
      type = "launch",
      workflow = workflow_file,
      session_id = session_id,
    }
  end

  -- Parse resume message: "Resuming session [session_id]"
  session_id = clean_line:match("Resuming%s+session%s+%[([^%]]+)%]")
  if session_id then
    return {
      type = "resume",
      session_id = session_id,
    }
  end

  -- Parse execution time: "Duration: 5m 23s"
  local duration = clean_line:match("Duration:%s*([%dhms ]+)")
  if duration then
    return {
      type = "duration",
      duration = duration,
    }
  end

  -- Parse CPU hours: "CPU hours: 42.5"
  local cpu_hours = clean_line:match("CPU hours:%s*([%d%.]+)")
  if cpu_hours then
    return {
      type = "cpu_hours",
      value = tonumber(cpu_hours),
    }
  end

  -- Parse success rate: "Succeeded: 42 | Cached: 8 | Failed: 2"
  local succeeded = clean_line:match("Succeeded:%s*(%d+)")
  local cached = clean_line:match("Cached:%s*(%d+)")
  local failed = clean_line:match("Failed:%s*(%d+)")
  if succeeded then
    return {
      type = "summary",
      succeeded = tonumber(succeeded),
      cached = tonumber(cached) or 0,
      failed = tonumber(failed) or 0,
    }
  end

  -- Parse INFO/WARN/ERROR messages
  local level, message = clean_line:match("^%[([%u]+)%]%s*(.*)")
  if level then
    return {
      type = "log",
      level = level,
      message = message,
    }
  end

  -- Return raw line if no pattern matched
  return {
    type = "raw",
    line = clean_line,
  }
end

--- Parse multiple lines and build workflow state
--- @param lines table Array of output lines
--- @return table Workflow state information
function M.parse_output(lines)
  local state = {
    status = "unknown",
    processes = {},
    session_id = nil,
    workflow = nil,
    progress = {
      completed = 0,
      total = 0,
      percentage = 0,
    },
    summary = {
      succeeded = 0,
      cached = 0,
      failed = 0,
    },
    duration = nil,
    cpu_hours = nil,
    logs = {},
    executor = nil,
  }

  for _, line in ipairs(lines) do
    local parsed = M.parse_line(line)

    if parsed then
      if parsed.type == "launch" then
        state.workflow = parsed.workflow
        state.session_id = parsed.session_id
        state.status = "running"
      elseif parsed.type == "resume" then
        state.session_id = parsed.session_id
        state.status = "running"
      elseif parsed.type == "progress" then
        state.progress.completed = parsed.completed
        state.progress.total = parsed.total
        state.progress.percentage = parsed.percentage

        -- Track per-process progress
        if parsed.process then
          if not state.processes[parsed.process] then
            state.processes[parsed.process] = {
              name = parsed.process,
              completed = 0,
              total = 0,
              samples = {},
            }
          end
          state.processes[parsed.process].completed = parsed.completed
          state.processes[parsed.process].total = parsed.total

          if parsed.sample then
            table.insert(state.processes[parsed.process].samples, parsed.sample)
          end
        end
      elseif parsed.type == "status" then
        state.status = parsed.status
      elseif parsed.type == "summary" then
        state.summary = {
          succeeded = parsed.succeeded,
          cached = parsed.cached,
          failed = parsed.failed,
        }
      elseif parsed.type == "duration" then
        state.duration = parsed.duration
      elseif parsed.type == "cpu_hours" then
        state.cpu_hours = parsed.value
      elseif parsed.type == "executor" then
        state.executor = {
          type = parsed.executor,
          count = parsed.count,
        }
      elseif parsed.type == "log" then
        table.insert(state.logs, {
          level = parsed.level,
          message = parsed.message,
        })
      elseif parsed.type == "raw" and parsed.line ~= "" then
        -- Store non-empty raw lines as INFO logs
        table.insert(state.logs, {
          level = "INFO",
          message = parsed.line,
        })
      end
    end
  end

  return state
end

--- Get process status based on progress
--- @param process table Process information
--- @return string Status: "completed", "running", or "pending"
function M.get_process_status(process)
  if process.completed == 0 then
    return "pending"
  elseif process.completed >= process.total then
    return "completed"
  else
    return "running"
  end
end

--- Format duration for display
--- @param duration string Duration string from Nextflow
--- @return string Formatted duration
function M.format_duration(duration)
  if not duration then
    return "00:00:00"
  end
  return duration
end

--- Calculate overall progress percentage
--- @param completed number
--- @param total number
--- @return number Percentage (0-100)
function M.calculate_percentage(completed, total)
  if total == 0 then
    return 0
  end
  return math.floor((completed / total) * 100)
end

return M
