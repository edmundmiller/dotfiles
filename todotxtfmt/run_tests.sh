#!/bin/bash

# Test runner for todo.txt formatter
# Tests various scenarios and documents edge cases

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

FORMATTER="./todotxtfmt"
TEST_DIR="testdata"
TEMP_DIR=$(mktemp -d)
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo_info() { echo -e "${GREEN}INFO:${RESET} $*"; }
echo_warn() { echo -e "${YELLOW}WARN:${RESET} $*"; }
echo_error() { echo -e "${RED}ERROR:${RESET} $*"; }
echo_pass() { echo -e "✅ ${GREEN}PASS:${RESET} $*"; }
echo_fail() { echo -e "❌ ${RED}FAIL:${RESET} $*"; }

run_test() {
    local test_name="$1"
    local input_file="$2"
    local should_error="${3:-false}"
    
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    # Copy test file to temp location
    local temp_file="$TEMP_DIR/$(basename "$input_file")"
    cp "$input_file" "$temp_file"
    
    echo_info "Testing: $test_name"
    
    # Run formatter
    "$FORMATTER" --dry-run --diff --verbose "$temp_file" > "$TEMP_DIR/output.log" 2>&1
    local exit_code=$?
    
    if [ "$should_error" = "true" ]; then
        if [ $exit_code -eq 1 ]; then
            echo_pass "$test_name - Correctly failed as expected"
            PASS_COUNT=$((PASS_COUNT + 1))
            return 0
        else
            echo_fail "$test_name - Expected error (exit 1) but got exit code $exit_code"
            cat "$TEMP_DIR/output.log"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return 1
        fi
    else
        if [ $exit_code -eq 0 ] || [ $exit_code -eq 2 ]; then
            # Exit 0 = no changes, Exit 2 = changes found in dry-run
            echo_pass "$test_name - Formatter processed successfully (exit $exit_code)"
            PASS_COUNT=$((PASS_COUNT + 1))
            return 0
        else
            echo_fail "$test_name - Unexpected formatter error (exit $exit_code)"
            cat "$TEMP_DIR/output.log"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return 1
        fi
    fi
}

echo "🧪 Todo.txt Formatter Test Suite"
echo "================================="
echo

# Build formatter if needed
if [ ! -x "$FORMATTER" ]; then
    echo_info "Building formatter..."
    go build -o todotxtfmt cmd/todotxtfmt/main.go
fi

echo_info "Running comprehensive tests..."
echo

# Test 1: Basic Formatting
echo_info "📂 Basic Formatting Tests"
run_test "Basic formatting scenarios" "$TEST_DIR/basic_formatting.txt"

# Test 2: Metadata and Issue Tracking
echo_info "📂 Metadata and Issue Tracking Tests"
run_test "Metadata and issue tracking" "$TEST_DIR/metadata_tracking.txt"

# Test 3: Special Characters
echo_info "📂 Special Characters Tests"
run_test "Special characters and URLs" "$TEST_DIR/special_characters.txt"

# Test 4: Edge Cases
echo_info "📂 Edge Cases Tests"
run_test "Edge cases and potential errors" "$TEST_DIR/edge_cases.txt"

# Test 5: Our original sample
echo_info "📂 Original Sample Tests"
run_test "Original sample file" "$TEST_DIR/sample.txt"

# Test 6: Empty file
echo_info "📂 Empty File Test"
echo "" > "$TEMP_DIR/empty.txt"
run_test "Empty file handling" "$TEMP_DIR/empty.txt"

# Test 7: Single line
echo_info "📂 Single Line Test"  
echo "(A) Single task" > "$TEMP_DIR/single.txt"
run_test "Single line file" "$TEMP_DIR/single.txt"

# Test 8: Invalid date format (should error)
echo_info "📂 Error Condition Tests"
echo "Task due:invalid-date-format" > "$TEMP_DIR/invalid_date.txt"
run_test "Invalid date format" "$TEMP_DIR/invalid_date.txt" "true"

# Performance Test with large file
echo_info "📂 Performance Test"
{
    for i in {1..1000}; do
        echo "(A) Task $i +project @context issue:TASK-$i priority:high due:2025-12-31"
        echo "(B) Another task $i @work +webapp pr:$i reviewer:dev"
        echo "x 2025-01-01 Completed task $i +maintenance status:done"
    done
} > "$TEMP_DIR/large_file.txt"
run_test "Large file (3000 tasks)" "$TEMP_DIR/large_file.txt"

echo
echo "=== Test Summary ==="
echo "Total Tests: $TOTAL_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo_pass "All tests passed! 🎉"
    exit 0
else
    echo_fail "$FAIL_COUNT test(s) failed"
    exit 1
fi