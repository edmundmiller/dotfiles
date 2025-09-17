#!/usr/bin/env bash

# Simple working examples to demonstrate bashunit

function test_basic_string_operations() {
  local greeting="Hello World"
  
  assert_contains "$greeting" "Hello"
  assert_contains "$greeting" "World"
}

function test_command_output() {
  local output
  output=$(echo "Testing bashunit")
  
  assert_equals "Testing bashunit" "$output"
  assert_contains "$output" "bashunit"
}

function test_exit_codes() {
  # Test successful command
  bash -c "exit 0"
  assert_equals 0 $?
  
  # Test failing command
  bash -c "exit 1"
  assert_equals 1 $?
}

function test_file_operations() {
  local temp_file
  temp_file=$(mktemp)
  
  echo "Test content" > "$temp_file"
  
  # Test file exists and has correct content
  local content
  content=$(cat "$temp_file")
  assert_equals "Test content" "$content"
  
  # Clean up
  rm -f "$temp_file"
}

function test_numeric_comparisons() {
  local count=5
  
  assert_equals 5 "$count"
  assert_equals "5" "$count"  # String comparison also works
}

function test_task_script_help_substring() {
  # A working version of the help test - just check for key substrings
  local output
  output=$(bash task.sh help)
  
  assert_contains "$output" "Interactive todo.txt task review tool"
  assert_contains "$output" "USAGE:"
  assert_contains "$output" "review"
}

function test_task_invalid_command_properly() {
  # Test that demonstrates proper error testing
  local output
  output=$(bash task.sh nonexistent 2>&1)
  local exit_code=$?
  
  assert_contains "$output" "Unknown command"
  assert_equals 1 "$exit_code"
}
