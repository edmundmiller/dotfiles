#!/bin/bash
# Simple test framework for todo.txt actions
# Based on bash unit testing patterns

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Test setup
setup() {
    # Create temporary directory for test files
    export TEST_DIR=$(mktemp -d)
    export TEST_TODO_FILE="$TEST_DIR/todo.txt"
    export TEST_TODO_DIR="$TEST_DIR"
    
    # Mock environment variables
    export TODO_FILE="$TEST_TODO_FILE"
    export TODO_DIR="$TEST_TODO_DIR"
    export TODO_FULL_SH="todo.sh"
    
    # Clear Jira config for clean tests
    unset JIRA_BASE_URL
    unset OPEN_JIRA_BASE_URL
}

# Test teardown
teardown() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
    unset TEST_DIR TEST_TODO_FILE TEST_TODO_DIR
    unset TODO_FILE TODO_DIR TODO_FULL_SH
    unset JIRA_BASE_URL OPEN_JIRA_BASE_URL
}

# Start a test
test_start() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
}

# End a test
test_end() {
    teardown
}

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" == "$actual" ]]; then
        printf "${GREEN}✓${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Expected '$expected', got '$actual'"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}✗${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Expected '$expected', got '$actual'"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        printf "${GREEN}✓${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Found '$needle' in output"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}✗${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Expected to find '$needle' in '$haystack'"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        printf "${GREEN}✓${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Did not find '$needle' in output (correct)"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}✗${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Expected NOT to find '$needle' in '$haystack'"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" -eq "$actual" ]]; then
        printf "${GREEN}✓${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Exit code $actual (expected)"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}✗${NC} "
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Expected exit code $expected, got $actual"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run a test function
run_test() {
    local test_name="$1"
    echo
    printf "${YELLOW}Running:${NC} $test_name\n"
    test_start "$test_name"
    
    # Run the test function
    if declare -f "$test_name" > /dev/null; then
        "$test_name"
    else
        echo "Test function '$test_name' not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    test_end
}

# Test summary
print_summary() {
    echo
    echo "=================================="
    echo "Test Summary:"
    echo "  Total:  $TESTS_RUN"
    printf "  Passed: ${GREEN}$TESTS_PASSED${NC}\n"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        printf "  Failed: ${RED}$TESTS_FAILED${NC}\n"
        echo "=================================="
        exit 1
    else
        echo "  Failed: $TESTS_FAILED"
        echo "=================================="
        printf "${GREEN}All tests passed!${NC}\n"
        exit 0
    fi
}

# Helper to create test todo file
create_test_todo() {
    cat > "$TEST_TODO_FILE" << EOF
$1
EOF
}

# Helper to run open action and capture output
run_open_action() {
    local item_num="$1"
    local action_script="${2:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")/open}"
    
    # Mock the 'open' command to avoid actually opening browsers during tests
    local mock_open="$TEST_DIR/open"
    cat > "$mock_open" << EOF
#!/bin/bash
echo "MOCK_OPEN: \$@" >> "$TEST_DIR/open_calls.log"
for url in "\$@"; do
    echo "Would open: \$url"
done
EOF
    chmod +x "$mock_open"
    
    # Run the action with PATH modified to use our mock 'open' command
    local output
    output=$(PATH="$TEST_DIR:$PATH" bash "$action_script" "$item_num" 2>&1)
    local exit_code=$?
    
    # Output the result
    echo "$output"
    return $exit_code
}
