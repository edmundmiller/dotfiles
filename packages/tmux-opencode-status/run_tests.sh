#!/usr/bin/env bash
# Test runner for tmux-opencode-status
#
# Usage: ./run_tests.sh
#
# Environment variables:
#   OPENCODE_STATUS_FINISHED_DELAY - Override finished state delay (default: 0 for tests)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to instant tests (no delay)
export OPENCODE_STATUS_FINISHED_DELAY="${OPENCODE_STATUS_FINISHED_DELAY:-0}"

echo "Running tmux-opencode-status tests..."
echo ""

# Run all test files
PASS=0
FAIL=0

for test_file in "$SCRIPT_DIR"/tests/test_*.sh; do
    if [[ -f "$test_file" ]]; then
        echo ">>> $(basename "$test_file")"
        echo ""
        if bash "$test_file"; then
            ((PASS++))
        else
            ((FAIL++))
        fi
        echo ""
    fi
done

# Final summary
echo "============================="
echo "Test suites: $PASS passed, $FAIL failed"
echo "============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
