#!/usr/bin/env bash
# Test that pi settings.jsonc converts to valid JSON after nix-darwin rebuild.
# Run: bash modules/shell/pi/test-settings-json.sh
#
# This catches:
# - Inline // comments not stripped
# - Trailing commas not removed
# - Any other JSONC→JSON conversion failures
set -euo pipefail

settings="$HOME/.pi/agent/settings.json"
failures=0

if [ ! -f "$settings" ]; then
  echo "SKIP: $settings not found (pi module not enabled?)"
  exit 0
fi

# Validate JSON
if python3 -m json.tool "$settings" > /dev/null 2>&1; then
  echo "PASS: valid JSON"
else
  echo "FAIL: invalid JSON"
  python3 -m json.tool "$settings" 2>&1 || true
  failures=$((failures + 1))
fi

# Check no full-line // comments leaked through
if grep -E '^\s*//' "$settings" > /dev/null 2>&1; then
  echo "FAIL: full-line // comments found"
  grep -nE '^\s*//' "$settings"
  failures=$((failures + 1))
else
  echo "PASS: no full-line comments"
fi

# Check no inline comments after JSON values
# Matches lines with // outside of quoted strings (heuristic)
if grep -E ',\s*//' "$settings" > /dev/null 2>&1; then
  echo "FAIL: inline // comments found"
  grep -nE ',\s*//' "$settings"
  failures=$((failures + 1))
else
  echo "PASS: no inline comments"
fi

# Check no trailing commas before ] or }
if python3 -c "
import re, sys
text = open('$settings').read()
# trailing comma before closing bracket/brace (ignoring whitespace/newlines)
if re.search(r',\s*[\]\}]', text):
    print('trailing comma detected')
    sys.exit(1)
" 2>&1; then
  echo "PASS: no trailing commas"
else
  echo "FAIL: trailing commas found"
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  echo "--- $failures check(s) failed ---"
  exit 1
fi
echo "--- all checks passed ---"
