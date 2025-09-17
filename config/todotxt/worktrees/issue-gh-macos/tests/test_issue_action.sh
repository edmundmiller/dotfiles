#!/bin/bash
# Tests for the issue action using bashunit

set_up() {
  export TEST_TODO_FILE=$(mktemp)
  export TEST_DONE_FILE=$(mktemp)  
  export TODO_FILE="$TEST_TODO_FILE"
  export DONE_FILE="$TEST_DONE_FILE"
  export TODOTXT_NOTIFY="1"
  export GITHUB_TOKEN="mock_token_123"
  
  # Mock external commands
  mock uname echo "Darwin"  # Simulate macOS
  mock gh _mock_gh_command
  mock osascript echo "notification sent"
  mock open echo "opened"
  mock curl echo "{'state': 'closed'}"
  mock python3 echo "Python 3.12.0"
  
  # Mock TODO_FULL_SH for integration
  export TODO_FULL_SH="bash -c _mock_todo_sh"
  mock _mock_todo_sh _mock_todo_sh_func
}

tear_down() {
  [[ -f "$TEST_TODO_FILE" ]] && rm -f "$TEST_TODO_FILE"
  [[ -f "$TEST_DONE_FILE" ]] && rm -f "$TEST_DONE_FILE"
  unset TODO_FILE DONE_FILE TODOTXT_NOTIFY GITHUB_TOKEN TODO_FULL_SH
}

# Mock functions
function _mock_gh_command() {
  case "$1" in
    "auth")
      case "$2" in
        "status") echo "✓ Logged in to github.com"; return 0 ;;
        "token") echo "$GITHUB_TOKEN"; return 0 ;;
      esac
      ;;
    "issue")
      case "$2" in
        "view") echo "opened issue in browser"; return 0 ;;
        "close") echo "closed issue"; return 0 ;;
        "create") echo "https://github.com/test/repo/issues/1"; return 0 ;;
      esac
      ;;
  esac
}

function _mock_todo_sh_func() {
  case "$1" in
    "show") echo "Mock todo item content" ;;
    "done") echo "TODO: $2 marked as done." ;;
  esac
}

function test_issue_usage() {
  local output
  output=$(../issue usage 2>&1)
  
  assert_contains "Handle linked issues" "$output"
  assert_contains "issue sync" "$output"
  assert_contains "issue close" "$output"
}

function test_issue_view_gh_token() {
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  spy gh
  local output
  output=$(../issue 1 2>&1)
  
  # Should use gh CLI for viewing
  assert_have_been_called gh
}

function test_issue_view_issue_url() {
  echo "Fix bug issue:https://github.com/owner/repo/issues/123" > "$TEST_TODO_FILE"
  
  local output  
  output=$(../issue 1 2>&1)
  
  # Should handle issue URL format
  assert_same 0 $?
}

function test_issue_close_with_gh_integration() {
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  spy gh
  spy _mock_todo_sh_func
  
  local output
  output=$(../issue close 1 2>&1)
  
  # Should call gh to close issue and todo.sh to mark done
  assert_have_been_called gh
  assert_have_been_called _mock_todo_sh_func
}

function test_issue_close_fallback_to_curl() {
  echo "Fix bug issue:https://github.com/owner/repo/issues/123" > "$TEST_TODO_FILE"
  
  # Mock gh as unavailable
  mock command echo ""
  mock command return 1
  
  spy curl
  spy _mock_todo_sh_func
  
  local output
  output=$(../issue close 1 2>&1)
  
  # Should fallback to curl when gh unavailable
  assert_have_been_called curl
  assert_have_been_called _mock_todo_sh_func
}

function test_macos_notification_integration() {
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  spy osascript
  
  local output
  output=$(../issue 1 2>&1)
  
  # Should use osascript for notifications on macOS
  assert_have_been_called osascript
}

function test_linux_compatibility() {
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  # Mock Linux environment
  mock uname echo "Linux"
  mock notify-send echo "linux notification"
  mock xdg-open echo "linux open"
  
  spy notify-send
  spy xdg-open
  
  # Test notification (simulate TODOTXT_NOTIFY trigger)
  local output
  output=$(../issue 1 2>&1)
  
  # On Linux, should not call osascript (macOS shims not active)
  assert_not_called osascript
}

function test_gh_authentication_detection() {
  # Test with authenticated gh
  mock gh <<EOF
case "\$1" in
  "auth") 
    case "\$2" in 
      "status") echo "✓ Logged in"; return 0 ;;
    esac ;;
esac
EOF
  
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  spy gh
  local output
  output=$(../issue 1 2>&1)
  
  assert_have_been_called gh
}

function test_gh_unavailable_fallback() {
  # Mock gh as unavailable
  mock command return 1
  
  echo "Fix bug gh:owner/repo#123" > "$TEST_TODO_FILE"
  
  spy open  # Should fallback to direct URL opening
  
  local output
  output=$(../issue 1 2>&1)
  
  assert_have_been_called open
}

function test_url_parsing_both_formats() {
  # Test parsing both gh: and issue: formats in one item
  echo "Fix gh:owner1/repo1#123 and also issue:https://github.com/owner2/repo2/issues/456" > "$TEST_TODO_FILE"
  
  local output
  output=$(../issue 1 2>&1)
  
  # Should handle both formats (prefer issue: format as per script logic)
  assert_same 0 $?
}

function test_no_issue_found() {
  echo "Regular todo with no issue links" > "$TEST_TODO_FILE"
  
  local output
  output=$(../issue 1 2>&1)
  
  assert_contains "No issue found" "$output"
  assert_not_same 0 $?
}

function test_sync_functionality() {
  spy python3
  spy _mock_todo_sh_func
  
  local output
  output=$(../issue sync 2>&1)
  
  # Should attempt to run the Python helper
  assert_have_been_called python3
}

function test_multiple_close_operations() {
  echo "Fix gh:owner/repo#123" > "$TEST_TODO_FILE"
  echo "Fix gh:owner/repo#456" >> "$TEST_TODO_FILE"
  
  spy gh
  spy _mock_todo_sh_func
  
  local output
  output=$(../issue close 1 2 2>&1)
  
  # Should close multiple issues
  assert_have_been_called_times 4 gh  # 2 auth checks + 2 close calls
  assert_have_been_called_times 2 _mock_todo_sh_func  # 2 done calls
}

function test_grep_compatibility_fix() {
  echo "Fix issue:https://github.com/owner/repo/issues/123" > "$TEST_TODO_FILE"
  
  # Test that script uses -E instead of -P for macOS compatibility
  local output
  output=$(../issue 1 2>&1)
  
  # Should not fail with grep errors
  assert_not_contains "grep: invalid option" "$output"
  assert_same 0 $?
}
