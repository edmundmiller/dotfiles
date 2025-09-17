#!/bin/bash
# Run all bashunit tests

set -euo pipefail

cd "$(dirname "$0")"

echo "🧪 Running todo.txt action tests with bashunit"
echo "=============================================="
echo

# Run open action tests
echo "📂 Testing open action..."
./tests/bashunit tests/test_open_action.sh

echo
echo "🔗 Testing issue action..."  
./tests/bashunit tests/test_issue_action.sh

echo
echo "✅ All tests completed!"

# Optional: Run with coverage or verbose output
if [[ "${1:-}" == "--verbose" ]]; then
    echo
    echo "🔍 Running with verbose output..."
    ./tests/bashunit --verbose tests/test_*.sh
fi
