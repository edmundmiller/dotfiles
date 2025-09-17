#!/usr/bin/env bash

# Integration and edge case tests for task.sh

# Test environment variables
function test_environment_variables() {
  local output
  
  # Test default TODO_DIR behavior
  unset TODO_DIR TODO_FILE DONE_FILE REVIEW_DAYS
  
  # Test help output includes correct default paths
  output=$(bash task.sh help 2>&1)
  assert_contains "$output" "~/todo/todo.txt"
  assert_contains "$output" "REVIEW_DAYS   Default days before review needed (default: 14)"
}

# Test dependency checking
function test_dependency_checks() {
  local output exit_code
  
  # Test python3 dependency check (by temporarily hiding python3)
  # Note: This test assumes python3 is available; in a real test environment,
  # you might mock the `command -v` check
  
  # Create a wrapper script that hides python3
  local temp_script=$(mktemp)
  cat > "$temp_script" << 'EOF'
#!/usr/bin/env bash
# Mock script that simulates missing python3
if [[ "$1" == "command" && "$2" == "-v" && "$3" == "python3" ]]; then
  exit 1
fi
# For other commands, use the original bash
exec /bin/bash "$@"
EOF
  chmod +x "$temp_script"
  
  # Run task.sh with the wrapper (this would need more sophisticated mocking in practice)
  # For now, let's just test that the script includes the dependency check
  local script_content
  script_content=$(cat task.sh)
  assert_contains "$script_content" "command -v python3"
  assert_contains "$script_content" "python3 not found"
  
  # Clean up
  rm -f "$temp_script"
}

# Test date calculation edge cases
function test_date_edge_cases() {
  # Source the script to access its functions
  source task.sh
  
  # Test with invalid dates
  local result
  result=$(days_between "invalid-date" "2024-01-01" 2>/dev/null || echo "error")
  assert_equals "9999" "$result"  # Should return fallback value
  
  # Test with same dates
  result=$(days_between "2024-01-01" "2024-01-01")
  assert_equals "0" "$result"
  
  # Test leap year calculation
  result=$(days_between "2024-02-28" "2024-03-01")  # 2024 is a leap year
  assert_equals "2" "$result"  # Feb 29 exists in leap years
}

# Test tag parsing edge cases
function test_tag_parsing_edge_cases() {
  # Source the script to access its functions
  source task.sh
  
  # Test tag at beginning of line
  local line1="due:2024-01-01 Task with due at start"
  local due_value
  due_value=$(get_tag "$line1" "due")
  assert_equals "2024-01-01" "$due_value"
  
  # Test multiple spaces around tags
  local line2="Task    due:2024-01-01    with  spaces"
  due_value=$(get_tag "$line2" "due")
  assert_equals "2024-01-01" "$due_value"
  
  # Test tag with special characters
  local line3="Task project:some-project_name123"
  local project_value
  project_value=$(get_tag "$line3" "project")
  assert_equals "some-project_name123" "$project_value"
  
  # Test non-existent tag
  local missing_value
  missing_value=$(get_tag "$line1" "nonexistent")
  assert_equals "" "$missing_value"
  
  # Test tag removal edge cases
  local stripped
  stripped=$(remove_tag "due:2024-01-01 Task" "due")
  assert_equals "Task" "$stripped"
  
  # Test removing tag that doesn't exist
  stripped=$(remove_tag "Regular task" "due")
  assert_equals "Regular task" "$stripped"
}

# Test priority parsing edge cases
function test_priority_edge_cases() {
  # Source the script to access its functions
  source task.sh
  
  # Test lowercase priority (should not be recognized)
  local prio
  prio=$(get_priority "(a) lowercase priority")
  assert_equals "" "$prio"
  
  # Test priority without space
  prio=$(get_priority "(A)no space")
  assert_equals "" "$prio"  # Should not match without proper space
  
  # Test multiple priorities (should get first one)
  prio=$(get_priority "(A) First (B) Second")
  assert_equals "A" "$prio"
  
  # Test priority in middle of line (should not match)
  prio=$(get_priority "Task with (A) in middle")
  assert_equals "" "$prio"
}

# Test completed task detection edge cases
function test_completed_task_edge_cases() {
  # Source the script to access its functions
  source task.sh
  
  # Test various completion formats
  local completed_formats=(
    "x 2024-01-01 Task completed"
    "x Task without date"
    "x  Task with extra spaces"
  )
  
  for format in "${completed_formats[@]}"; do
    if ! is_done "$format"; then
      assert_equals "should detect completed: $format" "failed"
    fi
  done
  
  # Test non-completed formats
  local non_completed_formats=(
    " x Task with leading space"
    "X 2024-01-01 Capital X"
    "Task x in middle"
    "xx 2024-01-01 Double x"
  )
  
  for format in "${non_completed_formats[@]}"; do
    if is_done "$format"; then
      assert_equals "should not detect completed: $format" "failed"
    fi
  done
}

# Test needs_review complex scenarios
function test_needs_review_complex_scenarios() {
  # Source the script to access its functions
  source task.sh
  
  # Set test environment
  REVIEW_DAYS=7
  
  # Calculate test dates
  local today_date
  today_date=$(today)
  
  local due_tomorrow
  due_tomorrow=$(python3 - <<'PY'
import datetime
print((datetime.date.today() + datetime.timedelta(days=1)).strftime("%Y-%m-%d"))
PY
)
  
  local due_next_week
  due_next_week=$(python3 - <<'PY'
import datetime
print((datetime.date.today() + datetime.timedelta(days=7)).strftime("%Y-%m-%d"))
PY
)
  
  local overdue_date
  overdue_date=$(python3 - <<'PY'
import datetime
print((datetime.date.today() - datetime.timedelta(days=1)).strftime("%Y-%m-%d"))
PY
)
  
  # Task due tomorrow (should need review)
  local urgent_task="Urgent task due:$due_tomorrow"
  if ! needs_review "$urgent_task"; then
    assert_equals "task due tomorrow should need review" "failed"
  fi
  
  # Task due next week with recent review (should not need review)
  local future_task="Future task due:$due_next_week reviewed:$today_date"
  if needs_review "$future_task"; then
    assert_equals "recently reviewed future task should not need review" "failed"
  fi
  
  # Overdue task (should need review regardless of review date)
  local overdue_task="Overdue task due:$overdue_date reviewed:$today_date"
  if ! needs_review "$overdue_task"; then
    assert_equals "overdue task should need review" "failed"
  fi
}

# Test normalize_space function
function test_normalize_space_function() {
  # Source the script to access its functions
  source task.sh
  
  local test_cases=(
    "  leading spaces"
    "trailing spaces  "
    "  both sides  "
    "multiple    internal    spaces"
    $'\t\ttabs and\t\tspaces\t\t'
    ""  # empty string
    "   "  # only spaces
  )
  
  local expected=(
    "leading spaces"
    "trailing spaces"
    "both sides"
    "multiple internal spaces"
    "tabs and spaces"
    ""
    ""
  )
  
  for i in "${!test_cases[@]}"; do
    local result
    result=$(normalize_space "${test_cases[$i]}")
    assert_equals "${expected[$i]}" "$result"
  done
}

# Test file operations safety
function test_file_operations_safety() {
  local temp_dir
  temp_dir=$(mktemp -d)
  local temp_todo="$temp_dir/test_todo.txt"
  
  # Create test todo file
  cat > "$temp_todo" << 'EOF'
Task 1
Task 2
Task 3
EOF
  
  # Source the script and test load_tasks
  source task.sh
  TODO_FILE="$temp_todo"
  
  # Test loading tasks
  load_tasks
  assert_equals "3" "${#TASKS[@]}"
  assert_equals "Task 1" "${TASKS[0]}"
  assert_equals "Task 2" "${TASKS[1]}"
  assert_equals "Task 3" "${TASKS[2]}"
  
  # Test save_tasks creates backup
  TASKS[0]="Modified Task 1"
  save_tasks
  
  # Check that backup was created
  local backup_count
  backup_count=$(ls "$temp_todo.bak."* 2>/dev/null | wc -l)
  assert_greater_than "$backup_count" 0
  
  # Check that file was updated
  local first_line
  first_line=$(head -n1 "$temp_todo")
  assert_equals "Modified Task 1" "$first_line"
  
  # Clean up
  rm -rf "$temp_dir"
}

# Test configuration file parsing
function test_config_file_parsing() {
  local temp_dir
  temp_dir=$(mktemp -d)
  local temp_todo="$temp_dir/test.txt"
  
  echo "Test task" > "$temp_todo"
  
  # Source the script
  source task.sh
  
  # Test read_config with various options
  read_config --file "$temp_todo" --days 21
  assert_equals "$temp_todo" "$TODO_FILE"
  assert_equals "21" "$REVIEW_DAYS"
  
  # Test short form of days option
  read_config --file "$temp_todo" -d 30
  assert_equals "$temp_todo" "$TODO_FILE"
  assert_equals "30" "$REVIEW_DAYS"
  
  # Test with unknown options (should be ignored)
  read_config --file "$temp_todo" --unknown option --days 7
  assert_equals "$temp_todo" "$TODO_FILE"
  assert_equals "7" "$REVIEW_DAYS"
  
  # Clean up
  rm -rf "$temp_dir"
}
