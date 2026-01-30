# Nextflow Runner for Neovim

A custom buffer UI plugin for running Nextflow workflows with live progress tracking, inspired by the [NeovimConf 2024 talk](https://github.com/chipsenkbeil/neovimconf-2024-talk) patterns.

## Features

- **Custom Buffer UI**: Beautiful box-drawn interface with real-time updates
- **Live Progress Tracking**: See workflow progress, task status, and logs in real-time
- **Async Execution**: Non-blocking workflow execution using Neovim's job control
- **Smart Output Parsing**: Extracts progress, status, and errors from Nextflow output
- **Resume Support**: One-key resume of failed workflows
- **Interactive Controls**: Stop, resume, and view logs without leaving Neovim

## Architecture

```
nextflow-runner/
├── init.lua       # Core module: API, state management, timer control
├── executor.lua   # Async execution: jobstart, process control, root detection
├── parser.lua     # Output parsing: regex patterns, state extraction
└── ui.lua         # Custom buffer: rendering, highlighting, keymaps
```

### Design Principles

- **Modular**: Each component has a single responsibility
- **Pure Lua**: No external dependencies beyond Neovim built-ins
- **Async-first**: Non-blocking execution preserves editor responsiveness
- **Extensible**: Clear extension points for future features

## Usage

### Basic Commands

```vim
:NextflowRun              " Run current workflow with UI
:NextflowResume           " Resume last workflow
:NextflowStop             " Stop running workflow
:NextflowShow             " Show/toggle UI
:NextflowLogs             " Open full .nextflow.log file
```

### Keybindings

In Nextflow files (`.nf`):

| Key           | Action                      |
| ------------- | --------------------------- |
| `<leader>nrw` | Run workflow with custom UI |
| `<leader>nrW` | Run with resume flag        |
| `<leader>nrR` | Resume last workflow        |
| `<leader>nrs` | Show runner UI              |
| `<leader>nrx` | Stop workflow               |
| `<leader>nrh` | Hide runner UI              |
| `<leader>nrL` | Show full logs              |
| `<leader>nrd` | Show DAG (planned)          |

Inside the runner buffer:

| Key | Action          |
| --- | --------------- |
| `r` | Resume workflow |
| `s` | Stop workflow   |
| `l` | Show full logs  |
| `q` | Quit/hide UI    |

### Configuration

```lua
require("nextflow-runner").setup({
  auto_scroll = true,        -- Auto-scroll to bottom of output
  refresh_rate = 500,        -- UI refresh rate in milliseconds
  default_args = {},         -- Default arguments for nextflow run
  log_level = "info",        -- "silent", "info", or "debug"
  auto_show = true,          -- Auto-show UI when running workflow
})
```

## Extension Potentials

The plugin is designed with clear extension points for future enhancements. Here are the key areas for expansion:

### 1. Seqera Platform (Tower) Integration

**Location**: `executor.lua`

Add Tower API support for launching and monitoring workflows on Seqera Platform:

```lua
-- In executor.lua
M.tower_config = {
  url = nil,           -- Tower URL (e.g., "https://tower.seqera.io")
  token = nil,         -- API token from environment or config
  workspace = nil,     -- Tower workspace ID
  compute_env = nil,   -- Compute environment ID
}

function M.execute_on_tower(workflow_file, opts)
  -- Build Tower-specific command
  local cmd = {
    "tw", "launch",
    workflow_file,
    "--workspace", M.tower_config.workspace,
    "--compute-env", M.tower_config.compute_env,
  }

  -- Return run ID for monitoring
  -- Poll Tower API for status updates
  -- Parse Tower-specific output
end

function M.monitor_tower_run(run_id)
  -- Poll Tower API: GET /workflow/{id}
  -- Update state with Tower-specific data
  -- Return enhanced state with Tower metadata
end
```

**Parser enhancements** (`parser.lua`):

```lua
-- Parse Tower-specific output
function M.parse_tower_line(line)
  -- Parse: "Workflow submitted to Tower [run_id]"
  -- Parse: "Tower run URL: https://tower.seqera.io/..."
  -- Parse Tower status updates
end
```

**UI enhancements** (`ui.lua`):

```lua
-- Add Tower-specific UI elements
function M.render_tower_info(state)
  -- Display Tower run URL (clickable)
  -- Show compute environment details
  -- Display Tower-specific metrics
end
```

### 2. DAG Visualization

**Location**: `init.lua` + new `dag.lua` module

Implement workflow DAG visualization in multiple modes:

```lua
-- In dag.lua (new file)
local M = {}

function M.generate_ascii_dag(workflow_file)
  -- Parse nextflow.config and workflow files
  -- Build process dependency graph
  -- Render ASCII art DAG in buffer
  return ascii_dag_lines
end

function M.generate_graphviz_dag(workflow_file)
  -- Execute: nextflow view workflow.nf -preview
  -- Convert DOT format to buffer-friendly representation
  -- Or open in external viewer
end

function M.show_interactive_dag()
  -- Create navigable buffer with process nodes
  -- Allow clicking/entering nodes to see details
  -- Highlight currently executing processes
end
```

**Integration** (`init.lua`):

```lua
function M.show_dag()
  local dag = require("nextflow-runner.dag")

  -- Option 1: ASCII in buffer
  dag.show_interactive_dag()

  -- Option 2: Open SVG/HTML in browser
  -- dag.generate_graphviz_dag()

  -- Option 3: Live DAG with execution highlighting
  -- dag.show_live_dag(M.current_state)
end
```

### 3. Task Resource Monitoring

**Location**: `parser.lua` + `ui.lua`

Parse and display resource usage for each task:

```lua
-- In parser.lua
function M.parse_resource_usage(line)
  -- Parse: "Task CPU: 95.2%, Memory: 2.1 GB / 4.0 GB"
  -- Extract from .nextflow/history or trace files
  return {
    type = "resources",
    cpu_percent = 95.2,
    memory_used = "2.1 GB",
    memory_total = "4.0 GB",
    time_elapsed = "00:05:23",
  }
end

function M.parse_trace_file(trace_file)
  -- Read .nextflow/trace.txt
  -- Parse CSV-like format
  -- Return per-task resource data
end
```

**UI enhancements** (`ui.lua`):

```lua
function M.render_resource_graphs(state)
  -- ASCII bar charts for CPU/memory usage
  -- Per-process resource breakdown
  -- Highlight resource bottlenecks

  -- Example:
  -- PROCESS_A
  --   CPU:    [████████░░] 82%
  --   Memory: [███░░░░░░░] 35% (1.2G / 4.0G)
  --   Time:   00:03:42
end
```

### 4. Interactive Task Navigation

**Location**: `ui.lua` + `init.lua`

Make the UI interactive for exploring task details:

```lua
-- In ui.lua
function M.setup_interactive_keymaps()
  -- Navigate between processes with j/k
  -- Press <CR> to see task details
  -- Press <C-]> to jump to work directory
  -- Press <C-o> to jump back
end

function M.show_task_details(process_name, task_id)
  -- Open new split with task details:
  -- - Command executed
  -- - Exit status
  -- - stdout/stderr
  -- - Work directory path
  -- - Resource usage
end
```

**Integration** (`init.lua`):

```lua
function M.open_task_work_dir(process_name, task_id)
  -- Find work directory from .nextflow/history
  local work_dir = find_task_work_dir(task_id)

  -- Open in file explorer or terminal
  vim.cmd("tcd " .. work_dir)
  vim.cmd("edit " .. work_dir .. "/.command.sh")
end
```

### 5. Workflow Parameter UI

**Location**: New `params.lua` module

Interactive parameter selection before running:

```lua
-- In params.lua
local M = {}

function M.parse_params_from_config(workflow_file)
  -- Parse nextflow.config for params
  -- Extract from workflow definition
  return {
    { name = "input", type = "path", default = "data/*.fastq" },
    { name = "outdir", type = "path", default = "results" },
    { name = "max_cpus", type = "number", default = 8 },
  }
end

function M.show_param_selector(params)
  -- Create interactive form in buffer
  -- Allow editing parameter values
  -- Return selected params as CLI args
end
```

**Integration** (`init.lua`):

```lua
function M.run_with_params()
  local params_module = require("nextflow-runner.params")
  local params = params_module.parse_params_from_config()

  params_module.show_param_selector(params, function(selected_params)
    M.run({ args = selected_params })
  end)
end
```

### 6. Workflow History Browser

**Location**: New `history.lua` module

Browse previous workflow runs and their results:

```lua
-- In history.lua
local M = {}

function M.list_runs(root)
  -- Parse .nextflow.log
  -- Extract session IDs, timestamps, status
  return runs_list
end

function M.show_history_browser()
  -- Create buffer with run history
  -- Allow selecting runs to:
  --   - Resume
  --   - View logs
  --   - Compare parameters
  --   - Analyze resource usage
end

function M.compare_runs(run1_id, run2_id)
  -- Show diff of parameters
  -- Compare execution times
  -- Highlight changed processes
end
```

### 7. nf-test Integration

**Location**: Integration with existing `neotest-nftest` adapter

Add "Run and Test" workflow:

```lua
-- In init.lua
function M.run_and_test(opts)
  -- Run workflow first
  M.run(opts)

  -- On completion, automatically run nf-test
  -- Show combined results in UI
end

function M.show_test_coverage()
  -- Parse nf-test results
  -- Show which processes have tests
  -- Highlight untested processes
end
```

### 8. Multi-Workflow Management

**Location**: `init.lua` (state management)

Support running multiple workflows simultaneously:

```lua
-- In init.lua
M.jobs = {}  -- Map of job_id -> job_data

function M.run_multi(workflows)
  -- Run multiple workflows in parallel
  -- Track each in M.jobs table
  -- Show all in tabbed or split UI
end

function M.show_job_list()
  -- List all running/completed jobs
  -- Allow switching between job views
end
```

### 9. Profile Selection

**Location**: `executor.lua`

Add support for Nextflow profiles:

```lua
-- In executor.lua
function M.list_profiles(root)
  -- Parse nextflow.config for profile blocks
  return { "standard", "docker", "singularity", "cluster" }
end

function M.build_command(workflow_file, opts)
  -- Add profile selection
  if opts.profile then
    table.insert(cmd, "-profile")
    table.insert(cmd, opts.profile)
  end
end
```

**UI for profile selection**:

```lua
-- Show profile picker before running
vim.ui.select(profiles, {
  prompt = "Select Nextflow profile:",
}, function(selected)
  M.run({ profile = selected })
end)
```

### 10. Custom Output Exporters

**Location**: New `exporters.lua` module

Export execution data in various formats:

```lua
-- In exporters.lua
local M = {}

function M.export_to_json(state, output_file)
  -- Export current state as JSON
  -- Useful for CI/CD integration
end

function M.export_to_html(state, output_file)
  -- Generate HTML report
  -- Include charts and graphs
end

function M.export_to_markdown(state, output_file)
  -- Generate markdown summary
  -- Useful for documentation
end
```

## Extension Guidelines

When extending this plugin:

1. **Maintain modularity**: Keep concerns separated (parsing, execution, UI)
2. **Use async patterns**: Never block the editor with long-running operations
3. **Follow the parser pattern**: Add new `parse_*` functions for new output types
4. **Extend state, not behavior**: Add new fields to state object rather than changing core logic
5. **Update UI incrementally**: Use `vim.schedule_wrap()` for UI updates from async contexts
6. **Test with real workflows**: Always validate against actual Nextflow execution

## API Reference

### Public API (`init.lua`)

```lua
-- Setup
require("nextflow-runner").setup(opts)

-- Execution control
require("nextflow-runner").run(opts)        -- opts: {workflow, resume, args}
require("nextflow-runner").resume()
require("nextflow-runner").stop()

-- UI control
require("nextflow-runner").show()
require("nextflow-runner").hide()
require("nextflow-runner").toggle()
require("nextflow-runner").show_logs()
require("nextflow-runner").show_dag()

-- State queries
require("nextflow-runner").get_status()     -- Returns current state
require("nextflow-runner").is_running()     -- Returns boolean
```

### Parser API (`parser.lua`)

```lua
local parser = require("nextflow-runner.parser")

-- Line parsing
parser.parse_line(line)                     -- Returns parsed data or nil

-- State building
parser.parse_output(lines)                  -- Returns complete workflow state

-- Utilities
parser.get_process_status(process)          -- Returns "completed"|"running"|"pending"
parser.format_duration(duration)
parser.calculate_percentage(completed, total)
```

### Executor API (`executor.lua`)

```lua
local executor = require("nextflow-runner.executor")

-- Execution
executor.execute(workflow_file, opts, on_output, on_exit)  -- Returns job handle
executor.stop(job)
executor.is_running(job)

-- Utilities
executor.find_root(start_path)              -- Returns project root
executor.build_command(workflow_file, opts) -- Returns command array
executor.get_last_session(root)             -- Returns session ID
executor.check_nextflow()                   -- Returns boolean
```

### UI API (`ui.lua`)

```lua
local ui = require("nextflow-runner.ui")

-- Buffer management
ui.get_or_create_buffer()                   -- Returns buffer number
ui.show()                                    -- Returns window number
ui.hide()
ui.toggle()

-- Rendering
ui.render(state)                            -- Render state to buffer
ui.clear()                                  -- Clear buffer content
ui.auto_scroll(enabled)                     -- Auto-scroll to bottom

-- Interactivity
ui.setup_keymaps(on_resume, on_stop, on_logs, on_quit)
```

## Testing

### Unit Testing

Test individual parser patterns:

```lua
local parser = require("nextflow-runner.parser")

-- Test progress parsing
local line = "[42/50] process > FASTQC (sample_1)"
local result = parser.parse_line(line)
assert(result.type == "progress")
assert(result.completed == 42)
assert(result.total == 50)
```

### Integration Testing

Create test workflows in `tests/fixtures/`:

```groovy
// tests/fixtures/simple.nf
process sayHello {
    output:
    stdout

    script:
    """
    echo "Hello, World!"
    """
}

workflow {
    sayHello | view
}
```

Run and verify:

```vim
:NextflowRun tests/fixtures/simple.nf
```

## Contributing

When contributing extensions:

1. Add new modules to `lua/nextflow-runner/`
2. Update this README with new features and APIs
3. Add examples to `tests/fixtures/` if applicable
4. Update `init.lua` to expose new public APIs
5. Document configuration options in plugin config

## License

This plugin follows the dotfiles repository license.

## Acknowledgments

- Architecture inspired by [NeovimConf 2024 talk](https://github.com/chipsenkbeil/neovimconf-2024-talk)
- Integrates with [nf-test Neotest adapter](../neotest-nftest/)
- Part of the [Nextflow language support](../plugins/lang-nextflow.lua) ecosystem
