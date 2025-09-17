#!/usr/bin/env bash

# tracktime_additional_test.sh - Comprehensive additional unit tests using bashunit
# Tests advanced tracktime functionality and edge cases

# Test configuration
TRACKTIME_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/../tracktime"
TEST_BASE_DIR="/tmp/tracktime_additional_test"

# Setup function runs before each test
function set_up() {
    # Create unique test directory for this test
    export TEST_DIR="$TEST_BASE_DIR/$$_$(date +%s%N)"
    export TEST_TODO_DIR="$TEST_DIR/todo"
    export TEST_TODO_FILE="$TEST_TODO_DIR/todo.txt"
    
    mkdir -p "$TEST_TODO_DIR"
    
    # Create sample todo.txt with test tasks
    cat > "$TEST_TODO_FILE" << 'EOF'
Write project documentation +work @office
Implement time tracking feature +dev @coding
Review pull requests +dev @review
(A) Fix critical bug +dev @urgent due:2025-09-15
Plan team meeting +management @meeting rec:1w
EOF

    # Set environment for tracktime
    export TODO_DIR="$TEST_TODO_DIR"
    export TODO_FILE="$TEST_TODO_FILE"
    export TRACKTIME_NOTIFICATIONS=false  # Disable notifications for testing
    export TRACKTIME_LOG="$TEST_TODO_DIR/tracktime.log"
}

# Cleanup function runs after each test
function tear_down() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

# Test helper functions
function tracktime() {
    "$TRACKTIME_SCRIPT" "$@"
}

function get_todo_content() {
    cat "$TEST_TODO_FILE" 2>/dev/null || echo ""
}

function get_log_content() {
    cat "$TEST_TODO_DIR/tracktime.log" 2>/dev/null || echo ""
}

function current_task_exists() {
    [ -f "$TEST_TODO_DIR/.tracktime_current" ]
}

function get_current_task_info() {
    cat "$TEST_TODO_DIR/.tracktime_current" 2>/dev/null || echo ""
}

# =============================================================================
# EDGE CASE TESTS - Basic Functionality
# =============================================================================

function test_start_nonexistent_task_returns_error() {
    # Starting task #99 (doesn't exist) should show task not found but still work
    local output exit_code
    output=$(tracktime start 99 2>&1) && exit_code=0 || exit_code=$?
    
    # Should work but show "Task #99 (not found)"
    assert_equals 0 "$exit_code"
    assert_contains "Task #99 (not found)" "$output"
    assert_true current_task_exists
}

function test_pause_when_no_task_active_fails() {
    # Pausing when nothing is running should return error
    local output exit_code
    output=$(tracktime pause 2>&1) && exit_code=0 || exit_code=$?
    
    assert_equals 1 "$exit_code"
    assert_contains "No task is currently being tracked" "$output"
    assert_false current_task_exists
}

function test_stop_when_no_task_active_fails() {
    # Stopping when nothing is running should return error
    local output exit_code
    output=$(tracktime stop 2>&1) && exit_code=0 || exit_code=$?
    
    assert_equals 1 "$exit_code"
    assert_contains "No task is currently being tracked" "$output"
    assert_false current_task_exists
}

function test_switch_to_same_task_works() {
    # Start task 1, then switch to task 1 again
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    
    local output
    output=$(tracktime switch 1 2>&1)
    
    assert_contains "Started tracking" "$output"
    assert_true current_task_exists
}

function test_starting_new_task_while_active_switches_automatically() {
    # Start task 1
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    
    # Start task 2 should auto-switch  
    local output
    output=$(tracktime start 2 2>&1)
    
    assert_contains "Switching from current task" "$output"
    assert_contains "Started tracking" "$output"
    assert_true current_task_exists
    
    # Verify current task is now task 2
    local current_info
    current_info=$(get_current_task_info)
    assert_contains "Implement time tracking" "$current_info"
}

function test_pause_resume_maintains_state() {
    # Start, pause, and resume a task
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    
    # Pause
    tracktime pause >/dev/null 2>&1
    assert_false current_task_exists
    
    # Resume by starting same task
    local output
    output=$(tracktime start 1 2>&1)
    assert_contains "Started tracking" "$output"
    assert_true current_task_exists
    
    # Stop and verify time was recorded
    tracktime stop >/dev/null 2>&1
    local todo_content
    todo_content=$(get_todo_content)
    assert_contains "min:" "$todo_content"
}

# =============================================================================
# TODO.TXT INTEGRATION EDGE CASES
# =============================================================================

function test_tasks_with_existing_metadata_handled_properly() {
    # Test that tasks with existing due:, rec:, +project, @context work
    local output
    output=$(tracktime start 4 2>&1)  # Task 4 has due date and priority
    
    assert_contains "Started tracking" "$output"
    assert_contains "Fix critical bug" "$output"
    
    # Stop and check todo.txt
    tracktime stop >/dev/null 2>&1
    local todo_content
    todo_content=$(get_todo_content)
    
    # Should have #tracking removed and min: added, preserving other metadata
    assert_not_contains "#tracking" "$todo_content"
    assert_contains "min:" "$todo_content"
    assert_contains "due:2025-09-15" "$todo_content"
    assert_contains "(A)" "$todo_content"
}

function test_tracking_tag_only_on_current_task() {
    # Start task 1
    tracktime start 1 >/dev/null 2>&1
    local todo_content
    todo_content=$(get_todo_content)
    
    # Only task 1 should have #tracking
    local line1 line2
    line1=$(echo "$todo_content" | sed -n '1p')
    line2=$(echo "$todo_content" | sed -n '2p')
    
    assert_contains "#tracking" "$line1"
    assert_not_contains "#tracking" "$line2"
    
    # Switch to task 2
    tracktime switch 2 >/dev/null 2>&1
    todo_content=$(get_todo_content)
    
    line1=$(echo "$todo_content" | sed -n '1p')
    line2=$(echo "$todo_content" | sed -n '2p')
    
    # Now only task 2 should have #tracking
    assert_not_contains "#tracking" "$line1"
    assert_contains "#tracking" "$line2"
}

function test_min_field_updates_not_duplicates() {
    # Start and stop a task to get initial min: value
    tracktime start 1 >/dev/null 2>&1
    sleep 2
    tracktime stop >/dev/null 2>&1
    
    local first_todo
    first_todo=$(get_todo_content)
    local first_line
    first_line=$(echo "$first_todo" | sed -n '1p')
    
    # Should have exactly one min: field
    local min_count
    min_count=$(echo "$first_line" | grep -o "min:" | wc -l | tr -d ' ')
    assert_equals "1" "$min_count"
    
    # Start and stop again - should update, not duplicate
    tracktime start 1 >/dev/null 2>&1
    sleep 2  
    tracktime stop >/dev/null 2>&1
    
    local second_todo
    second_todo=$(get_todo_content)
    local second_line
    second_line=$(echo "$second_todo" | sed -n '1p')
    
    # Should still have exactly one min: field
    min_count=$(echo "$second_line" | grep -o "min:" | wc -l | tr -d ' ')
    assert_equals "1" "$min_count"
}

# =============================================================================  
# SESSION LOGGING TESTS
# =============================================================================

function test_all_actions_logged_with_timestamps() {
    # Test that START, PAUSE, RESUME, STOP, SWITCH are logged
    tracktime start "Test task" >/dev/null 2>&1
    sleep 1
    tracktime pause >/dev/null 2>&1
    tracktime start "Test task" >/dev/null 2>&1  # RESUME
    sleep 1
    tracktime switch 2 >/dev/null 2>&1  # SWITCH  
    sleep 1
    tracktime stop >/dev/null 2>&1
    
    local log_content
    log_content=$(get_log_content)
    
    # Should contain all action types
    assert_contains "START Test task" "$log_content"
    assert_contains "PAUSE Test task" "$log_content" 
    assert_contains "START Test task" "$log_content"  # Resume shows as START
    assert_contains "SWITCH Test task" "$log_content"
    assert_contains "START Implement time tracking" "$log_content"  # New task
    assert_contains "STOP Implement time tracking" "$log_content"
    
    # Should have valid timestamps
    local timestamp_pattern
    timestamp_pattern="[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}"
    local timestamp_count
    timestamp_count=$(echo "$log_content" | grep -cE "^$timestamp_pattern" || true)
    assert_true "test $timestamp_count -ge 5"  # At least 5 log entries
}

function test_log_entries_chronological_order() {
    # Generate several log entries and verify they're in order
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    tracktime switch 2 >/dev/null 2>&1
    sleep 1  
    tracktime stop >/dev/null 2>&1
    
    local log_content
    log_content=$(get_log_content)
    
    # Extract timestamps and verify they're in ascending order
    local timestamps
    timestamps=$(echo "$log_content" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
    
    # Convert to epoch seconds and check ordering
    local prev_epoch=0
    local current_epoch
    while IFS= read -r timestamp; do
        # Convert to epoch (try both macOS and Linux formats)
        current_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null) || \
        current_epoch=$(date -d "$timestamp" +%s 2>/dev/null) || current_epoch=999999999
        
        assert_true "test $current_epoch -ge $prev_epoch"
        prev_epoch=$current_epoch
    done <<< "$timestamps"
}

function test_log_survives_cleanup() {
    # Generate log entries 
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    tracktime stop >/dev/null 2>&1
    
    assert_file_exists "$TEST_TODO_DIR/tracktime.log"
    local log_before
    log_before=$(get_log_content)
    
    # Cleanup should not delete log file
    tracktime cleanup >/dev/null 2>&1
    
    assert_file_exists "$TEST_TODO_DIR/tracktime.log"
    local log_after
    log_after=$(get_log_content)
    
    # Log content should be preserved
    assert_equals "$log_before" "$log_after"
}

# =============================================================================
# TIME CALCULATION EDGE CASES
# =============================================================================

function test_very_short_sessions_handled_properly() {
    # Test sub-minute sessions (should round to 0 minutes)
    tracktime start 1 >/dev/null 2>&1
    sleep 1  # 1 second - should round to 0 minutes  
    tracktime stop >/dev/null 2>&1
    
    local todo_content
    todo_content=$(get_todo_content)
    assert_contains "min:0" "$todo_content"
}

function test_sessions_crossing_minute_boundaries() {
    # Test rounding behavior at 30-second boundary
    # 29 seconds should round to 0, 30 seconds should round to 1
    
    # First test: 29 seconds (should be 0 minutes)
    tracktime start 1 >/dev/null 2>&1
    sleep 29
    tracktime stop >/dev/null 2>&1
    
    local todo_content
    todo_content=$(get_todo_content)
    assert_contains "min:0" "$todo_content"
    
    # Reset for second test
    echo "Write project documentation +work @office" > "$TEST_TODO_FILE"
    
    # Second test: 31 seconds (should be 1 minute)  
    tracktime start 1 >/dev/null 2>&1
    sleep 31
    tracktime stop >/dev/null 2>&1
    
    todo_content=$(get_todo_content)
    assert_contains "min:1" "$todo_content"
}

# =============================================================================
# REPORTING AND SUMMARY TESTS
# =============================================================================

function test_summary_handles_empty_log() {
    # Test summary command with no tracked time
    local output
    output=$(tracktime summary 2>&1)
    
    assert_contains "No time tracking log found" "$output"
}

function test_log_command_date_filtering() {
    # Generate some log entries
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    tracktime stop >/dev/null 2>&1
    
    # Test log with different day filters
    local output_1day output_7days
    output_1day=$(tracktime log 1 2>&1)
    output_7days=$(tracktime log 7 2>&1)
    
    assert_contains "Time tracking log (last 1 days)" "$output_1day"
    assert_contains "Time tracking log (last 7 days)" "$output_7days" 
    assert_contains "START" "$output_1day"
    assert_contains "STOP" "$output_1day"
}

function test_report_handles_no_data() {
    # Test report command with no data
    local output
    output=$(tracktime report today 2>&1)
    
    assert_contains "No time tracked for this period" "$output"
}

# =============================================================================
# ERROR HANDLING AND ROBUSTNESS TESTS
# =============================================================================

function test_handles_missing_todo_file() {
    # Remove todo file
    rm -f "$TEST_TODO_FILE"
    
    # Starting a numbered task should still work (shows not found)
    local output
    output=$(tracktime start 1 2>&1)
    
    assert_contains "Started tracking" "$output"
    assert_contains "Task #1 (not found)" "$output"
    assert_true current_task_exists
}

function test_handles_unwritable_log_directory() {
    # Make log directory read-only
    local restricted_dir="$TEST_DIR/restricted"
    mkdir -p "$restricted_dir" 
    chmod 555 "$restricted_dir"  # Read/execute only
    
    export TRACKTIME_LOG="$restricted_dir/tracktime.log"
    
    # Should handle gracefully
    local output exit_code
    output=$(tracktime start "Test task" 2>&1) && exit_code=0 || exit_code=$?
    
    # Should not crash, but might not log
    assert_equals 0 "$exit_code"
    assert_contains "Started tracking" "$output"
    
    # Restore permissions for cleanup
    chmod 755 "$restricted_dir"
}

function test_handles_corrupted_current_task_file() {
    # Create corrupted current task file
    echo "invalid|format" > "$TEST_TODO_DIR/.tracktime_current"
    
    # Status should handle corruption gracefully
    local output exit_code
    output=$(tracktime status 2>&1) && exit_code=0 || exit_code=$?
    
    # Should either show error or handle gracefully
    assert_true "test $exit_code -eq 0 -o $exit_code -eq 1"
}

# =============================================================================
# CROSS-SESSION STATE MANAGEMENT
# =============================================================================

function test_state_persists_across_command_invocations() {
    # Start a task
    tracktime start 1 >/dev/null 2>&1
    
    # In a new invocation, status should show the task
    local output
    output=$(tracktime status 2>&1)
    
    assert_contains "Currently tracking" "$output"
    assert_contains "Write project documentation" "$output"
    
    # Stop should work from new invocation
    local stop_output  
    stop_output=$(tracktime stop 2>&1)
    assert_contains "Stopped tracking" "$stop_output"
}

function test_cleanup_restores_clean_state() {
    # Create some tracking state
    tracktime start 1 >/dev/null 2>&1
    assert_true current_task_exists
    
    # Cleanup should restore clean state
    local output
    output=$(tracktime cleanup 2>&1)
    
    assert_contains "Cleanup complete" "$output"
    assert_false current_task_exists
    
    # Status should show no active task
    local status_output exit_code
    status_output=$(tracktime status 2>&1) && exit_code=0 || exit_code=$?
    assert_equals 1 "$exit_code"
    assert_contains "No task is currently being tracked" "$status_output"
}

function test_cleanup_handles_no_state_gracefully() {
    # Cleanup when no state exists should work
    assert_false current_task_exists
    
    local output exit_code
    output=$(tracktime cleanup 2>&1) && exit_code=0 || exit_code=$?
    
    assert_equals 0 "$exit_code" 
    assert_contains "Cleanup complete" "$output"
    assert_false current_task_exists
}

# =============================================================================
# CONFIGURATION AND ENVIRONMENT TESTS
# =============================================================================

function test_respects_notification_settings() {
    # Test with notifications disabled (already set in setup)
    export TRACKTIME_NOTIFICATIONS=false
    
    # Should work without trying to send notifications
    local output
    output=$(tracktime start 1 2>&1)
    
    assert_contains "Started tracking" "$output"
    assert_true current_task_exists
}

function test_respects_custom_log_location() {
    # Test custom log file location
    local custom_log="$TEST_DIR/custom_tracktime.log"
    export TRACKTIME_LOG="$custom_log"
    
    tracktime start 1 >/dev/null 2>&1
    sleep 1
    tracktime stop >/dev/null 2>&1
    
    # Should create log at custom location
    assert_file_exists "$custom_log"
    local log_content
    log_content=$(cat "$custom_log")
    assert_contains "START" "$log_content"
    assert_contains "STOP" "$log_content"
}

function test_handles_missing_required_env_vars() {
    # Test handled in main test file, but verify here too
    local output exit_code
    output=$(bash -c 'unset TODO_DIR; "'$TRACKTIME_SCRIPT'" status' 2>&1) && exit_code=0 || exit_code=$?
    
    assert_equals 1 "$exit_code"
    assert_contains "TODO_DIR" "$output"
}

# =============================================================================
# HELPER ASSERTIONS 
# =============================================================================

function assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    if [ ! -f "$file" ]; then
        fail "$message"
    fi
}

function assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"
    
    if [ -f "$file" ]; then
        fail "$message"  
    fi
}

# Note: Using bashunit's standard assert_contains which expects needle, haystack
function assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="${3:-Text should contain substring}"
    
    if ! echo "$haystack" | grep -qF "$needle"; then
        fail "$message: '$needle' not found in '$haystack'"
    fi
}

function assert_not_contains() {
    local needle="$1"
    local haystack="$2"
    local message="${3:-Text should not contain substring}"
    
    if echo "$haystack" | grep -qF "$needle"; then
        fail "$message: '$needle' found in '$haystack'"
    fi
}
