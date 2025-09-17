#!/usr/bin/env bash

# Test suite for task.sh CLI functionality

# Setup function to create test todo files
function setup_test_todo_file() {
  local test_file="$1"
  cat > "$test_file" << 'EOF'
(A) Important task due:2024-01-15
Buy groceries reviewed:2024-01-01
Call mom due:2024-01-20
Write documentation @work +project
x 2024-01-10 Completed task reviewed:2024-01-05
Fix bug in code @urgent
(B) Plan vacation reviewed:2023-12-01
Meeting with team due:2024-01-12 reviewed:2024-01-10
Review quarterly goals +planning
x 2024-01-08 Another completed task
EOF
}

# Test help command
function test_task_help_command() {
  local output
  output=$(bash task.sh help 2>&1)
  
  assert_contains "$output" "task.sh - Interactive todo.txt task review tool"
  assert_contains "$output" "USAGE:"
  assert_contains "$output" "COMMANDS:"
  assert_contains "$output" "review"
  assert_contains "$output" "help"
}

# Test help flag variations
function test_task_help_flags() {
  local output1 output2 output3
  
  output1=$(bash task.sh --help 2>&1)
  output2=$(bash task.sh -h 2>&1)
  output3=$(bash task.sh "" 2>&1)
  
  # All variations should produce help output
  assert_contains "$output1" "Interactive todo.txt task review tool"
  assert_contains "$output2" "Interactive todo.txt task review tool"
  assert_contains "$output3" "Interactive todo.txt task review tool"
}

# Test invalid command
function test_task_invalid_command() {
  local output exit_code
  
  output=$(bash task.sh invalid_command 2>&1)
  exit_code=$?
  
  assert_contains "$output" "Unknown command: invalid_command"
  assert_contains "$output" "Try: task.sh help"
  assert_equals 1 $exit_code
}

# Test file existence check
function test_task_missing_todo_file() {
  local output exit_code
  
  # Try to review a non-existent file
  output=$(bash task.sh review --file /nonexistent/todo.txt 2>&1)
  exit_code=$?
  
  assert_contains "$output" "todo file not found"
  assert_equals 1 $exit_code
}

# Test configuration parsing
function test_task_config_parsing() {
  local temp_todo_file output
  temp_todo_file=$(mktemp)
  
  # Create a minimal todo file
  echo "Test task" > "$temp_todo_file"
  
  # Mock gum to avoid interactive mode (this would be a more complex test)
  # For now, we'll test that the script can find the file correctly
  
  # Test that --file option is recognized (script should not complain about missing file)
  output=$(timeout 2s bash task.sh review --file "$temp_todo_file" 2>&1 || true)
  
  # Should not contain "file not found" error
  assert_not_contains "$output" "todo file not found: $temp_todo_file"
  
  # Clean up
  rm -f "$temp_todo_file"
}

# Test date utility functions (by sourcing the script)
function test_date_functions() {
  # Source the script to access its functions
  source task.sh
  
  # Test today function
  local today_output expected_date
  today_output=$(today)
  expected_date=$(date +%F)
  assert_equals "$expected_date" "$today_output"
  
  # Test days_between function
  local days_diff
  days_diff=$(days_between "2024-01-01" "2024-01-05")
  assert_equals "4" "$days_diff"
  
  # Test days_between with reversed dates
  days_diff=$(days_between "2024-01-05" "2024-01-01")
  assert_equals "-4" "$days_diff"
}

# Test older_than function
function test_older_than_function() {
  # Source the script to access its functions
  source task.sh
  
  # Test with a date that's 20 days old
  local old_date
  old_date=$(python3 - <<'PY'
import datetime
print((datetime.date.today() - datetime.timedelta(days=20)).strftime("%Y-%m-%d"))
PY
)
  
  # Should return true (exit code 0) for dates older than 14 days
  if older_than "$old_date" 14; then
    assert_equals "0" "0"  # Test passes if older_than returns true
  else
    assert_equals "should be true" "false"  # Test fails if older_than returns false
  fi
  
  # Test with a recent date
  local recent_date
  recent_date=$(python3 - <<'PY'
import datetime
print((datetime.date.today() - datetime.timedelta(days=5)).strftime("%Y-%m-%d"))
PY
)
  
  # Should return false (exit code 1) for dates newer than 14 days
  if older_than "$recent_date" 14; then
    assert_equals "should be false" "true"  # Test fails if older_than returns true
  else
    assert_equals "0" "0"  # Test passes if older_than returns false
  fi
}

# Test tag manipulation functions
function test_tag_functions() {
  # Source the script to access its functions
  source task.sh
  
  local test_line="Buy groceries @home due:2024-01-15 reviewed:2024-01-01"
  
  # Test has_tag function
  if has_tag "$test_line" "due"; then
    assert_equals "0" "0"  # has due tag
  else
    assert_equals "should have due tag" "false"
  fi
  
  if has_tag "$test_line" "priority"; then
    assert_equals "should not have priority tag" "true"
  else
    assert_equals "0" "0"  # doesn't have priority tag
  fi
  
  # Test get_tag function
  local due_value
  due_value=$(get_tag "$test_line" "due")
  assert_equals "2024-01-15" "$due_value"
  
  local reviewed_value
  reviewed_value=$(get_tag "$test_line" "reviewed")
  assert_equals "2024-01-01" "$reviewed_value"
  
  # Test set_tag function
  local modified_line
  modified_line=$(set_tag "$test_line" "priority" "A")
  assert_contains "$modified_line" "priority:A"
  
  # Test modifying existing tag
  modified_line=$(set_tag "$test_line" "due" "2024-01-20")
  assert_contains "$modified_line" "due:2024-01-20"
  assert_not_contains "$modified_line" "due:2024-01-15"
  
  # Test remove_tag function
  local stripped_line
  stripped_line=$(remove_tag "$test_line" "due")
  assert_not_contains "$stripped_line" "due:"
  assert_contains "$stripped_line" "reviewed:2024-01-01"
}

# Test priority functions
function test_priority_functions() {
  # Source the script to access its functions
  source task.sh
  
  local priority_line="(A) Important task"
  local no_priority_line="Regular task"
  
  # Test get_priority function
  local prio
  prio=$(get_priority "$priority_line")
  assert_equals "A" "$prio"
  
  prio=$(get_priority "$no_priority_line")
  assert_equals "" "$prio"
  
  # Test set_priority function
  local modified_line
  modified_line=$(set_priority "$no_priority_line" "B")
  assert_equals "(B) Regular task" "$modified_line"
  
  # Test removing priority
  modified_line=$(set_priority "$priority_line" "none")
  assert_equals "Important task" "$modified_line"
  
  # Test changing priority
  modified_line=$(set_priority "$priority_line" "C")
  assert_equals "(C) Important task" "$modified_line"
}

# Test is_done function
function test_is_done_function() {
  # Source the script to access its functions
  source task.sh
  
  local completed_task="x 2024-01-10 Completed task"
  local active_task="Active task"
  
  # Test completed task
  if is_done "$completed_task"; then
    assert_equals "0" "0"  # is done
  else
    assert_equals "should be done" "false"
  fi
  
  # Test active task
  if is_done "$active_task"; then
    assert_equals "should not be done" "true"
  else
    assert_equals "0" "0"  # is not done
  fi
}

# Test needs_review function with various scenarios
function test_needs_review_function() {
  # Source the script to access its functions
  source task.sh
  
  # Set REVIEW_DAYS for testing
  REVIEW_DAYS=14
  
  # Task with no reviewed tag - should need review
  local no_review_task="Buy groceries @home"
  if needs_review "$no_review_task"; then
    assert_equals "0" "0"  # needs review
  else
    assert_equals "task without review should need review" "false"
  fi
  
  # Completed task - should not need review
  local completed_task="x 2024-01-10 Completed task"
  if needs_review "$completed_task"; then
    assert_equals "completed task should not need review" "true"
  else
    assert_equals "0" "0"  # doesn't need review
  fi
  
  # Empty line - should not need review
  local empty_task=""
  if needs_review "$empty_task"; then
    assert_equals "empty task should not need review" "true"
  else
    assert_equals "0" "0"  # doesn't need review
  fi
  
  # Task with old reviewed date
  local old_reviewed_task="Task with old review reviewed:2023-01-01"
  if needs_review "$old_reviewed_task"; then
    assert_equals "0" "0"  # needs review due to old date
  else
    assert_equals "task with old review should need review" "false"
  fi
}
