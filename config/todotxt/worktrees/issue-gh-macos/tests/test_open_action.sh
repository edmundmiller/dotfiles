#!/bin/bash
# Tests for the open action using bashunit

set_up() {
  # Create temporary test environment
  export TEST_TODO_FILE=$(mktemp)
  export TODO_FILE="$TEST_TODO_FILE"
  
  # Mock open command to capture calls
  mock open echo "OPENED:"
}

tear_down() {
  [[ -f "$TEST_TODO_FILE" ]] && rm -f "$TEST_TODO_FILE"
  unset TODO_FILE TEST_TODO_FILE
}

function test_open_github_shorthand() {
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  local output
  output=$(../open 1 2>&1)
  
  assert_contains "Opening 1 link(s) from item 1" "$output"
  assert_contains "https://github.com/owner/repo/issues/123" "$output"
}

function test_open_multiple_github_tokens() {
  echo "Fix gh:owner1/repo1#123 and gh:owner2/repo2#456" > "$TEST_TODO_FILE"
  
  local output
  output=$(../open 1 2>&1)
  
  assert_contains "Opening 2 link(s) from item 1" "$output"
  assert_contains "https://github.com/owner1/repo1/issues/123" "$output"
  assert_contains "https://github.com/owner2/repo2/issues/456" "$output"
}

function test_open_jira_token_with_config() {
  echo "Fix bug jira:PROJ-123" > "$TEST_TODO_FILE"
  export JIRA_BASE_URL="https://company.atlassian.net"
  
  local output
  output=$(../open 1 2>&1)
  
  assert_contains "Opening 1 link(s) from item 1" "$output"
  assert_contains "https://company.atlassian.net/browse/PROJ-123" "$output"
  
  unset JIRA_BASE_URL
}

function test_open_mixed_tokens() {
  echo "Fix gh:owner/repo#123 and track jira:PROJ-456" > "$TEST_TODO_FILE"
  export JIRA_BASE_URL="https://company.atlassian.net"
  
  local output
  output=$(../open 1 2>&1)
  
  assert_contains "Opening 2 link(s) from item 1" "$output"
  assert_contains "github.com/owner/repo/issues/123" "$output"
  assert_contains "company.atlassian.net/browse/PROJ-456" "$output"
  
  unset JIRA_BASE_URL
}

function test_open_no_tokens_found() {
  echo "Regular todo item with no links" > "$TEST_TODO_FILE"
  
  local output
  output=$(../open 1 2>&1)
  local exit_code=$?
  
  assert_same 2 "$exit_code"
  assert_contains "No supported links found" "$output"
}

function test_open_invalid_item_number() {
  echo "Some todo" > "$TEST_TODO_FILE"
  
  local output
  output=$(../open 999 2>&1)
  local exit_code=$?
  
  assert_same 1 "$exit_code"
  assert_contains "Error: Item 999 not found" "$output"
}

function test_open_usage_display() {
  local output
  output=$(../open 2>&1)
  
  assert_contains "Usage: todo.sh open ITEM#" "$output"
  assert_contains "gh:owner/repo#123" "$output"
  assert_contains "jira:TICKET-123" "$output"
}

function test_github_url_parsing_edge_cases() {
  # Test complex repository names with dots, dashes, underscores
  echo "Fix gh:nf-core/modules#123 and gh:user.name/repo_name#456" > "$TEST_TODO_FILE"
  
  local output
  output=$(../open 1 2>&1)
  
  assert_contains "nf-core/modules/issues/123" "$output"
  assert_contains "user.name/repo_name/issues/456" "$output"
}

function test_jira_interactive_setup() {
  echo "Fix jira:PROJ-123" > "$TEST_TODO_FILE"
  # No JIRA_BASE_URL set - should prompt in interactive mode
  # We'll mock the input to simulate user providing base URL
  
  local output
  output=$(../open 1 < <(echo "company.atlassian.net") 2>&1)
  
  assert_contains "Enter Jira base" "$output"
}

function test_invalid_github_tokens_ignored() {
  echo "Invalid gh:owner#123 gh:owner/ gh:/repo#123" > "$TEST_TODO_FILE"
  
  local output
  output=$(../open 1 2>&1)
  local exit_code=$?
  
  assert_same 2 "$exit_code"
  assert_contains "No supported links found" "$output"
}
