#!/usr/bin/env bash

# Working examples demonstrating bashunit

function test_string_operations() {
  local greeting="Hello World"
  
  # assert_contains needle haystack (needle should be IN haystack)
  assert_contains "Hello" "$greeting"
  assert_contains "World" "$greeting"
  assert_contains "Hello World" "$greeting"
}

function test_command_output() {
  local output
  output=$(echo "Testing bashunit")
  
  assert_equals "Testing bashunit" "$output"
  assert_contains "bashunit" "$output"
  assert_contains "Testing" "$output"
}

function test_exit_codes() {
  # These worked in previous runs
  bash -c "exit 0"
  assert_equals 0 $?
  
  bash -c "exit 1"
  assert_equals 1 $?
}

function test_file_operations() {
  # This also worked before
  local temp_file
  temp_file=$(mktemp)
  
  echo "Test content" > "$temp_file"
  
  local content
  content=$(cat "$temp_file")
  assert_equals "Test content" "$content"
  
  rm -f "$temp_file"
}

function test_numeric_comparisons() {
  # This worked too
  local count=5
  
  assert_equals 5 "$count"
  assert_equals "5" "$count"
}
