#!/bin/bash
# test_tracktime.sh - Test suite for tracktime implementation
# Tests all functionality and edge cases

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKTIME_SCRIPT="$SCRIPT_DIR/tracktime"
TEST_DIR="/tmp/tracktime_test_$$"
TEST_TODO_DIR="$TEST_DIR/todo"
TEST_TODO_FILE="$TEST_TODO_DIR/todo.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
setup_test_env() {
    echo "Setting up test environment..."
    mkdir -p "$TEST_TODO_DIR"
    
    # Create sample todo.txt with test tasks
    cat > "$TEST_TODO_FILE" << 'EOF'
Write project documentation +work @office
Implement time tracking feature +dev @coding
Review pull requests +dev @review
(A) Fix critical bug +dev @urgent
Plan team meeting +management @meeting
EOF

    # Set environment for tracktime
    export TODO_DIR="$TEST_TODO_DIR"
    export TODO_FILE="$TEST_TODO_FILE"
    export TRACKTIME_NOTIFICATIONS=false  # Disable notifications for testing
}

cleanup_test_env() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -n "Testing $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if $test_function; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo -e "${RED}$message${NC}"
        echo "Expected: $expected"
        echo "Actual: $actual"
        return 1
    fi
}

assert_contains() {
    local text="$1"
    local substring="$2"
    local message="${3:-Text should contain substring}"
    
    if echo "$text" | grep -q "$substring"; then
        return 0
    else
        echo -e "${RED}$message${NC}"
        echo "Text: $text"
        echo "Should contain: $substring"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [ -f "$file" ]; then
        return 0
    else
        echo -e "${RED}$message${NC}"
        echo "File: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"
    
    if [ ! -f "$file" ]; then
        return 0
    else
        echo -e "${RED}$message${NC}"
        echo "File: $file"
        return 1
    fi
}

# Test functions

test_help_command() {
    local output
    output=$("$TRACKTIME_SCRIPT" help 2>&1)
    
    assert_contains "$output" "tracktime - Enhanced time tracking" &&
    assert_contains "$output" "USAGE:" &&
    assert_contains "$output" "tracktime start" &&
    assert_contains "$output" "EXAMPLES:"
}

test_status_no_task() {
    local output
    local exit_code=0
    
    output=$("$TRACKTIME_SCRIPT" status 2>&1) || exit_code=$?
    
    assert_equals "1" "$exit_code" "Should return exit code 1 when no task is tracked" &&
    assert_contains "$output" "No task is currently being tracked"
}

test_start_task_by_number() {
    local output
    output=$("$TRACKTIME_SCRIPT" start 1 2>&1)
    
    assert_contains "$output" "Started tracking:" &&
    assert_contains "$output" "Write project documentation" &&
    assert_file_exists "$TEST_TODO_DIR/.tracktime_current" &&
    assert_file_exists "$TEST_TODO_DIR/tracktime.log"
}

test_status_with_active_task() {
    # Start a task first
    "$TRACKTIME_SCRIPT" start 2 >/dev/null 2>&1
    sleep 1  # Let some time pass
    
    local output
    output=$("$TRACKTIME_SCRIPT" status 2>&1)
    
    assert_contains "$output" "Currently tracking:" &&
    assert_contains "$output" "Implement time tracking" &&
    assert_contains "$output" "Session time:"
}

test_stop_task() {
    # Start a task first
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 2  # Let some time pass
    
    local output
    output=$("$TRACKTIME_SCRIPT" stop 2>&1)
    
    assert_contains "$output" "Stopped tracking:" &&
    assert_contains "$output" "Session time:" &&
    assert_file_not_exists "$TEST_TODO_DIR/.tracktime_current"
}

test_pause_and_resume() {
    # Start a task
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    
    # Pause it
    local pause_output
    pause_output=$("$TRACKTIME_SCRIPT" pause 2>&1)
    assert_contains "$pause_output" "Paused tracking:"
    
    # Resume by starting the same task
    local resume_output
    resume_output=$("$TRACKTIME_SCRIPT" start 1 2>&1)
    assert_contains "$resume_output" "Started tracking:"
}

test_switch_tasks() {
    # Start first task
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    
    # Switch to second task
    local output
    output=$("$TRACKTIME_SCRIPT" switch 2 2>&1)
    
    assert_contains "$output" "Switching from current task" &&
    assert_contains "$output" "Started tracking:" &&
    assert_contains "$output" "Implement time tracking"
}

test_start_adhoc_task() {
    local task_desc="Write tests for tracktime +testing @dev"
    local output
    output=$("$TRACKTIME_SCRIPT" start "$task_desc" 2>&1)
    
    assert_contains "$output" "Started tracking:" &&
    assert_contains "$output" "Write tests for tracktime"
}

test_task_time_update_in_todo() {
    # Start and stop a task to accumulate time
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 2
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Check if time was added to todo.txt
    local todo_content
    todo_content=$(cat "$TEST_TODO_FILE")
    
    assert_contains "$todo_content" "min:" "Task should have time tracking info"
}

test_tracking_tag_management() {
    # Start a task
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    
    # Check that #tracking tag was added
    local todo_content
    todo_content=$(cat "$TEST_TODO_FILE")
    assert_contains "$todo_content" "#tracking" "Active task should have #tracking tag"
    
    # Stop the task
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Check that #tracking tag was removed
    todo_content=$(cat "$TEST_TODO_FILE")
    if echo "$todo_content" | grep -q "#tracking"; then
        echo "ERROR: #tracking tag should be removed after stopping"
        return 1
    fi
    
    return 0
}

test_log_functionality() {
    # Generate some activity
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Check log output
    local output
    output=$("$TRACKTIME_SCRIPT" log 1 2>&1)
    
    assert_contains "$output" "Time tracking log" &&
    assert_contains "$output" "START" &&
    assert_contains "$output" "STOP"
}

test_summary_functionality() {
    # Generate some activity
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Test summary for specific task
    local output
    output=$("$TRACKTIME_SCRIPT" summary 1 2>&1)
    
    assert_contains "$output" "Time summary for task #1:" &&
    assert_contains "$output" "Total time:"
    
    # Test overall summary
    output=$("$TRACKTIME_SCRIPT" summary 2>&1)
    assert_contains "$output" "Time summary for all tasks:"
}

test_report_functionality() {
    # Generate some activity
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Test today's report
    local output
    output=$("$TRACKTIME_SCRIPT" report today 2>&1)
    
    # Should contain report header and some data
    assert_contains "$output" "Time report for today:" &&
    assert_contains "$output" "TOTAL"
}

test_cleanup_functionality() {
    # Start a task and then cleanup
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    
    local output
    output=$("$TRACKTIME_SCRIPT" cleanup 2>&1)
    
    assert_contains "$output" "Cleanup complete" &&
    assert_file_not_exists "$TEST_TODO_DIR/.tracktime_current"
}

test_time_formatting() {
    # Test the format_duration function indirectly through status
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 2
    
    local output
    output=$("$TRACKTIME_SCRIPT" status 2>&1)
    
    # Should show time in readable format (e.g., "2s", "1m", etc.)
    if echo "$output" | grep -E "[0-9]+(s|m|h)" >/dev/null; then
        return 0
    else
        echo "Time format should be human readable (e.g., 2s, 1m, 1h30m)"
        return 1
    fi
}

test_error_handling() {
    # Test starting without argument
    local output
    local exit_code=0
    output=$("$TRACKTIME_SCRIPT" start 2>&1) || exit_code=$?
    
    assert_equals "1" "$exit_code" &&
    assert_contains "$output" "Error: Please specify"
    
    # Test invalid action
    exit_code=0
    output=$("$TRACKTIME_SCRIPT" invalid_action 2>&1) || exit_code=$?
    
    assert_equals "1" "$exit_code" &&
    assert_contains "$output" "Unknown action"
}

test_multiple_sessions_same_task() {
    # Start and stop task multiple times
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Get initial time
    local first_summary
    first_summary=$("$TRACKTIME_SCRIPT" summary 1 2>&1)
    
    # Work on it again
    "$TRACKTIME_SCRIPT" start 1 >/dev/null 2>&1
    sleep 1
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    # Get final time
    local second_summary
    second_summary=$("$TRACKTIME_SCRIPT" summary 1 2>&1)
    
    # Time should have increased
    if [ "$first_summary" = "$second_summary" ]; then
        echo "Time should accumulate across multiple sessions"
        return 1
    fi
    
    return 0
}

test_log_file_format() {
    # Generate activity and check log format
    "$TRACKTIME_SCRIPT" start "Test task +test @format" >/dev/null 2>&1
    sleep 1
    "$TRACKTIME_SCRIPT" stop >/dev/null 2>&1
    
    local log_file="$TEST_TODO_DIR/tracktime.log"
    assert_file_exists "$log_file"
    
    # Check log format: YYYY-MM-DD HH:MM:SS ACTION description
    local log_content
    log_content=$(cat "$log_file")
    
    if echo "$log_content" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} (START|STOP)" >/dev/null; then
        return 0
    else
        echo "Log format should be: YYYY-MM-DD HH:MM:SS ACTION description"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${YELLOW}Starting tracktime test suite...${NC}"
    echo
    
    # Setup
    trap cleanup_test_env EXIT
    setup_test_env
    
    # Run tests
    run_test "help command" test_help_command
    run_test "status with no task" test_status_no_task
    run_test "start task by number" test_start_task_by_number
    run_test "status with active task" test_status_with_active_task
    run_test "stop task" test_stop_task
    run_test "pause and resume" test_pause_and_resume
    run_test "switch tasks" test_switch_tasks
    run_test "start ad-hoc task" test_start_adhoc_task
    run_test "task time update in todo" test_task_time_update_in_todo
    run_test "tracking tag management" test_tracking_tag_management
    run_test "log functionality" test_log_functionality
    run_test "summary functionality" test_summary_functionality
    run_test "report functionality" test_report_functionality
    run_test "cleanup functionality" test_cleanup_functionality
    run_test "time formatting" test_time_formatting
    run_test "error handling" test_error_handling
    run_test "multiple sessions same task" test_multiple_sessions_same_task
    run_test "log file format" test_log_file_format
    
    # Results
    echo
    echo -e "${YELLOW}Test Results:${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Check if tracktime script exists
if [ ! -f "$TRACKTIME_SCRIPT" ]; then
    echo -e "${RED}Error: tracktime script not found at $TRACKTIME_SCRIPT${NC}"
    exit 1
fi

# Make sure tracktime is executable
if [ ! -x "$TRACKTIME_SCRIPT" ]; then
    echo -e "${RED}Error: tracktime script is not executable${NC}"
    exit 1
fi

# Run tests
main "$@"
