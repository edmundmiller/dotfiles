#!/usr/bin/env bash

# Simplified tests for task.sh to demonstrate working tests

# Test basic help command functionality
function test_help_shows_usage() {
  local output
  output=$(bash task.sh help 2>&1)
  
  # Check that help contains key information
  assert_contains "$output" "Interactive todo.txt task review tool"
  assert_contains "$output" "USAGE:"
  assert_contains "$output" "task.sh review"
}

# Test help command variations
function test_help_variations_work() {
  local help_output flag_output empty_output
  
  help_output=$(bash task.sh help 2>&1)
  flag_output=$(bash task.sh --help 2>&1)
  empty_output=$(bash task.sh 2>&1)
  
  # All should contain the tool description
  assert_contains "$help_output" "Interactive todo.txt task review tool"
  assert_contains "$flag_output" "Interactive todo.txt task review tool"
  assert_contains "$empty_output" "Interactive todo.txt task review tool"
}

# Test invalid command handling
function test_invalid_command_shows_error() {
  local output exit_code
  
  output=$(bash task.sh invalid_command 2>&1)
  exit_code=$?
  
  assert_contains "$output" "Unknown command: invalid_command"
  assert_contains "$output" "Try: task.sh help"
  assert_equals 1 $exit_code
}

# Test missing file error
function test_missing_file_error() {
  local output exit_code
  
  output=$(bash task.sh review --file /nonexistent/file.txt 2>&1)
  exit_code=$?
  
  assert_contains "$output" "todo file not found"
  assert_equals 1 $exit_code
}

# Test basic function sourcing
function test_basic_functions_exist() {
  # Source the script to access its functions
  source task.sh
  
  # Test today function returns valid date format
  local today_output
  today_output=$(today)
  assert_matches "$today_output" "[0-9]{4}-[0-9]{2}-[0-9]{2}"
  
  # Test days_between with simple calculation
  local days_diff
  days_diff=$(days_between "2024-01-01" "2024-01-05")
  assert_equals "4" "$days_diff"
}

# Test tag detection
function test_tag_detection() {
  source task.sh
  
  local test_line="Buy groceries @home due:2024-01-15"
  
  # Test has_tag function
  if has_tag "$test_line" "due"; then
    # Tag found - this is expected
    assert_equals "1" "1"
  else
    assert_fail "should have found due tag"
  fi
  
  # Test get_tag function
  local due_value
  due_value=$(get_tag "$test_line" "due")
  assert_equals "2024-01-15" "$due_value"
}

# Test priority detection
function test_priority_detection() {
  source task.sh
  
  local priority_line="(A) Important task"
  local no_priority_line="Regular task"
  
  # Test priority extraction
  local prio
  prio=$(get_priority "$priority_line")
  assert_equals "A" "$prio"
  
  prio=$(get_priority "$no_priority_line")
  assert_equals "" "$prio"
}

# Test completion detection
function test_completion_detection() {
  source task.sh
  
  local completed_task="x 2024-01-10 Completed task"
  local active_task="Active task"
  
  # Test completed task detection
  if is_done "$completed_task"; then
    assert_equals "1" "1"  # Expected - task is done
  else
    assert_fail "should detect completed task"
  fi
  
  # Test active task detection
  if is_done "$active_task"; then
    assert_fail "should not detect active task as done"
  else
    assert_equals "1" "1"  # Expected - task is not done
  fi
}

# Test normalize space function
function test_normalize_space() {
  source task.sh
  
  # Test various space normalization scenarios
  local result
  
  result=$(normalize_space "  leading spaces")
  assert_equals "leading spaces" "$result"
  
  result=$(normalize_space "trailing spaces  ")
  assert_equals "trailing spaces" "$result"
  
  result=$(normalize_space "multiple    internal    spaces")
  assert_equals "multiple internal spaces" "$result"
}

# Test script structure
function test_script_has_required_structure() {
  local script_content
  script_content=$(cat task.sh)
  
  # Test shebang
  assert_contains "$script_content" "#!/usr/bin/env bash"
  
  # Test main case statement
  assert_contains "$script_content" 'case "$CMD" in'
  assert_contains "$script_content" "review)"
  assert_contains "$script_content" "help|--help|-h|\"\")"
  
  # Test key functions exist
  assert_contains "$script_content" "today()"
  assert_contains "$script_content" "days_between()"
  assert_contains "$script_content" "has_tag()"
  assert_contains "$script_content" "get_tag()"
}
