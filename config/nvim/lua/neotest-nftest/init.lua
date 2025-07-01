local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")

local M = {}

--- @class neotest.Adapter
--- @field name string
M.name = "neotest-nftest"

--- Find the project root for nf-test
--- @param path string
--- @return string|nil
M.root = lib.files.match_root_pattern("nf-test.config", "nextflow.config", "main.nf")

--- Check if a file is an nf-test test file
--- @param file_path string
--- @return boolean
function M.is_test_file(file_path)
  if file_path == nil then
    return false
  end
  
  -- Check if it's a .nf.test file or in tests directory with .nf extension
  local is_test_file = vim.endswith(file_path, ".nf.test") or
                      (string.match(file_path, "/tests/") and vim.endswith(file_path, ".nf"))
  
  -- Additional check: look for nextflow_* test blocks in the file
  if not is_test_file and vim.endswith(file_path, ".nf") then
    local content = lib.files.read(file_path)
    if content then
      is_test_file = string.match(content, "nextflow_%w+%s*{") ~= nil
    end
  end
  
  return is_test_file
end

--- Filter directories that should be searched for test files
--- @param name string
--- @param rel_path string
--- @param root string
--- @return boolean
function M.filter_dir(name, rel_path, root)
  -- Include common test directories and avoid hidden directories
  return name ~= "node_modules" and name ~= ".git" and not vim.startswith(name, ".")
end

--- Discover test positions in a file
--- @param file_path string
--- @return neotest.Tree|nil
function M.discover_positions(file_path)
  local query = [[
    (call_expression
      function: (identifier) @func_name (#match? @func_name "^nextflow_(process|workflow|pipeline|function)$")
      arguments: (arguments
        (closure
          body: (statements
            (expression_statement
              (call_expression
                function: (field_expression
                  object: (identifier)
                  field: (identifier) @test_type (#eq? @test_type "test")
                )
                arguments: (arguments
                  (string_literal) @test_name
                  (closure) @test_body
                )
              )
            )
          )
        )
      )
    ) @test_block
  ]]

  local positions = lib.treesitter.parse_positions(file_path, query, {
    nested_tests = true,
    require_namespaces = false,
    position_id = function(position, parents)
      -- Create unique IDs for test positions
      if position.type == "test" then
        local parent_name = parents[#parents] and parents[#parents].id or "root"
        return parent_name .. "::" .. position.name
      end
      return position.name
    end,
  })

  return positions
end

--- Build the command to run tests
--- @param args neotest.RunArgs
--- @return neotest.RunSpec|nil
function M.build_spec(args)
  local position = args.tree:data()
  local results_path = async.fn.tempname() .. ".json"
  local cwd = M.root(position.path)
  
  if not cwd then
    logger.error("Could not find nf-test root directory")
    return nil
  end

  local command = { "nf-test" }
  
  -- Add test command
  table.insert(command, "test")
  
  -- Handle different position types
  if position.type == "file" then
    -- Run all tests in file
    table.insert(command, position.path)
  elseif position.type == "test" then
    -- Run specific test by name
    table.insert(command, position.path)
    table.insert(command, "--tag")
    table.insert(command, position.name)
  elseif position.type == "dir" then
    -- Run all tests in directory
    table.insert(command, position.path)
  end
  
  -- Add output format for results parsing
  table.insert(command, "--junitxml")
  table.insert(command, results_path)
  
  -- Add any additional arguments from configuration
  if args.extra_args then
    vim.list_extend(command, args.extra_args)
  end

  local strategy_config = {
    command = command,
    cwd = cwd,
    context = {
      results_path = results_path,
      pos_id = position.id,
    },
  }

  if args.strategy == "dap" then
    -- Debug configuration (nf-test doesn't have built-in debug support)
    logger.warn("Debug strategy not supported for nf-test")
    return nil
  end

  return strategy_config
end

--- Parse test results from nf-test output
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.results(spec, result, tree)
  local results = {}
  local context = spec.context
  
  -- Initialize default result for the position being tested
  local default_result = {
    status = result.code == 0 and "passed" or "failed",
    output = result.output,
  }
  
  -- Try to parse JUnit XML if it exists
  if context.results_path and lib.files.exists(context.results_path) then
    local junit_results = M.parse_junit_xml(context.results_path)
    for test_id, test_result in pairs(junit_results) do
      results[test_id] = test_result
    end
  else
    -- Fall back to parsing stdout/stderr
    results = M.parse_output(result.output, tree)
  end
  
  -- Ensure we have a result for the main position
  if not results[context.pos_id] then
    results[context.pos_id] = default_result
  end
  
  return results
end

--- Parse JUnit XML output from nf-test
--- @param xml_path string
--- @return table<string, neotest.Result>
function M.parse_junit_xml(xml_path)
  local results = {}
  local content = lib.files.read(xml_path)
  
  if not content then
    return results
  end
  
  -- Simple XML parsing for JUnit format
  -- This is a basic implementation - could be enhanced with proper XML parser
  for testcase in content:gmatch('<testcase[^>]*name="([^"]*)"[^>]*>.-</testcase>') do
    local test_name = testcase:match('name="([^"]*)"')
    local failure = testcase:match('<failure[^>]*>(.-)</failure>')
    local error = testcase:match('<error[^>]*>(.-)</error>')
    
    if test_name then
      results[test_name] = {
        status = (failure or error) and "failed" or "passed",
        errors = failure and { { message = failure } } or error and { { message = error } } or nil,
      }
    end
  end
  
  return results
end

--- Parse test output when JUnit XML is not available
--- @param output string
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.parse_output(output, tree)
  local results = {}
  
  -- Parse nf-test output format
  for line in output:gmatch("[^\r\n]+") do
    -- Look for test result lines like:
    -- "Test 'test_name' PASSED"
    -- "Test 'test_name' FAILED"
    local test_name, status = line:match("Test%s+'([^']+)'%s+(%w+)")
    
    if test_name and status then
      local test_status = string.lower(status) == "passed" and "passed" or "failed"
      
      -- Find the position ID for this test
      local position_id = nil
      for _, node in tree:iter() do
        local pos = node:data()
        if pos.name == test_name then
          position_id = pos.id
          break
        end
      end
      
      if position_id then
        results[position_id] = {
          status = test_status,
          output = line,
        }
      end
    end
  end
  
  return results
end

--- Get environment variables for test execution
--- @param position table
--- @return table<string, string>
function M.get_env()
  return {}
end

--- Setup function for adapter configuration
--- @param opts table|nil
--- @return neotest.Adapter
function M.setup(opts)
  opts = opts or {}
  
  -- Merge user options with defaults
  local adapter = vim.tbl_deep_extend("force", M, opts)
  
  return adapter
end

return M