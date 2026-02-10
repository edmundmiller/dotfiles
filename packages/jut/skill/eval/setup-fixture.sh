#!/usr/bin/env bash
set -euo pipefail

# Creates a disposable jj repository with jut skill installed.
# Outputs the fixture directory path on success.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUT_ROOT="${JUT_EVAL_JUT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
JUT_BIN="${JUT_EVAL_JUT_BIN:-$JUT_ROOT/target/debug/jut}"
SKILL_DIR="$JUT_ROOT/skill"

# Build jut if needed
if [[ ! -x "$JUT_BIN" ]]; then
  cargo build --manifest-path "$JUT_ROOT/Cargo.toml"
fi

# Create temp fixture
FIXTURE_DIR="$(mktemp -d)"
FIXTURE_DIR="$(cd "$FIXTURE_DIR" && pwd -P)"
KEEP_FIXTURES="${JUT_EVAL_KEEP_FIXTURES:-0}"

cleanup_fixture() {
  local exit_code=$?
  if [[ "$exit_code" -ne 0 && "$KEEP_FIXTURES" != "1" && -n "${FIXTURE_DIR:-}" && -d "$FIXTURE_DIR" ]]; then
    rm -rf "$FIXTURE_DIR"
  fi
}
trap cleanup_fixture ERR EXIT

# Initialize jj repo
cd "$FIXTURE_DIR"
jj git init >/dev/null
jj config set --repo user.name "Eval Fixture"
jj config set --repo user.email "eval@example.com"

# Install skill
"$JUT_BIN" skill install --target "$FIXTURE_DIR/.agents/skills/jut" >/dev/null
"$JUT_BIN" skill install --target "$FIXTURE_DIR/.claude/skills/jut" >/dev/null

# Verify
if ! "$JUT_BIN" -C "$FIXTURE_DIR" status --json >/dev/null 2>&1; then
  echo "Failed to initialize jj repo in fixture: $FIXTURE_DIR" >&2
  exit 1
fi

trap - ERR EXIT
echo "$FIXTURE_DIR"
