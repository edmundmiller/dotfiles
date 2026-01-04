#!/usr/bin/env bash
# Test suite for tmux-opencode-status state detection
#
# Usage: ./test_state_detection.sh
#
# Set OPENCODE_STATUS_FINISHED_DELAY=0 for fast tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counters
PASS=0
FAIL=0

# Current fixture file for mock
FIXTURE_FILE=""

# Mock tmux command - returns fixture content instead of real pane capture
tmux() {
    if [[ "$1" == "capture-pane" ]]; then
        cat "$FIXTURE_FILE" 2>/dev/null || echo ""
    fi
}
export -f tmux

# Source the script to get access to detect_state function
# We need to extract just the detect_state function since main() would fail
source_detect_state() {
    # Export the function from the script
    eval "$(sed -n '/^detect_state()/,/^}/p' "$SCRIPT_DIR/../opencode_status.sh")"
    eval "$(sed -n '/^ICON_/p' "$SCRIPT_DIR/../opencode_status.sh")"
    eval "$(sed -n '/^FINISHED_DELAY/p' "$SCRIPT_DIR/../opencode_status.sh")"
}

# Run a single test
run_test() {
    local name="$1"
    local fixture="$2"
    local expected="$3"

    FIXTURE_FILE="$FIXTURES_DIR/$fixture"

    if [[ ! -f "$FIXTURE_FILE" ]]; then
        echo -e "${YELLOW}SKIP${NC}: $name (fixture not found: $fixture)"
        return 0
    fi

    local result
    result=$(detect_state "%0" 2>/dev/null || echo "idle")

    if [[ "$result" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC}: $name"
        ((PASS++))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $name"
        echo "       Expected: $expected"
        echo "       Got:      $result"
        ((FAIL++))
        return 1
    fi
}

# Main test runner
main() {
    echo "================================"
    echo "tmux-opencode-status Test Suite"
    echo "================================"
    echo ""

    # Set delay to 0 for fast tests
    export OPENCODE_STATUS_FINISHED_DELAY=0

    # Source the detection function
    source_detect_state

    echo "Running state detection tests..."
    echo ""

    # Core state tests
    run_test "Idle state (empty pane)" "idle.txt" "idle" || true
    run_test "Busy state (spinner)" "busy_spinner.txt" "busy" || true
    run_test "Busy state (tool use)" "busy_tool.txt" "busy" || true
    run_test "Waiting state (permission prompt)" "waiting.txt" "waiting" || true
    run_test "Finished state (empty progress bar)" "finished.txt" "finished" || true
    run_test "Error state (Python traceback)" "error_crash.txt" "error" || true

    # False positive prevention tests
    echo ""
    echo "Running false positive prevention tests..."
    echo ""
    run_test "No false error on nix build output" "false_positive_nix_error.txt" "finished" || true

    # Summary
    echo ""
    echo "================================"
    echo "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
    echo "================================"

    [[ $FAIL -eq 0 ]] && exit 0 || exit 1
}

main "$@"
