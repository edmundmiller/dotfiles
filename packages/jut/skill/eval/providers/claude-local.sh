#!/usr/bin/env bash
set -euo pipefail

# Claude Code runner for jut skill eval.
# Creates a fixture, runs Claude with the prompt, captures command traces.
#
# Environment:
#   FIXTURE_DIR — pre-created fixture (if not set, creates one)
#   SETUP_COMMANDS — commands to run in fixture before prompt
#   PROMPT — the user prompt to send to Claude
#   KEEP_FIXTURES — set to 1 to preserve fixture dirs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Create fixture if not provided
if [[ -z "${FIXTURE_DIR:-}" ]]; then
  FIXTURE_DIR="$("$EVAL_DIR/setup-fixture.sh")"
fi

cd "$FIXTURE_DIR"

# Run setup commands if provided
if [[ -n "${SETUP_COMMANDS:-}" ]]; then
  eval "$SETUP_COMMANDS"
fi

# Run Claude with the prompt, capture output
# Uses --json for structured command trace output
RESULT=$(claude --cwd "$FIXTURE_DIR" --json \
  --allowedTools "Bash,Read,Write,Edit" \
  --print \
  "$PROMPT" 2>/dev/null || true)

# Capture repo state after agent finishes
JUT_BIN="${JUT_EVAL_JUT_BIN:-$(cd "$EVAL_DIR/../.." && pwd)/target/debug/jut}"
REPO_STATE=$("$JUT_BIN" -C "$FIXTURE_DIR" status --json 2>/dev/null || echo '{"error": "status failed"}')

# Output structured result
cat <<EOF
{
  "commands": $RESULT,
  "repoState": $REPO_STATE
}
EOF

# Cleanup
if [[ "${KEEP_FIXTURES:-0}" != "1" ]]; then
  rm -rf "$FIXTURE_DIR"
fi
