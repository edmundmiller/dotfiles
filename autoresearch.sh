#!/usr/bin/env bash
# Benchmark harness for the minimal Neovim config autoresearch loop.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

TMP_STARTUP="$(mktemp)"
trap 'rm -f "$TMP_STARTUP"' EXIT

# Fast boot check.
XDG_CONFIG_HOME="$ROOT_DIR/config" nvim --headless '+qa!' >/dev/null 2>&1

# Startup timing in ms: median of 5 startuptime samples.
declare -a STARTUP_SAMPLES=()
for _ in 1 2 3 4 5; do
  XDG_CONFIG_HOME="$ROOT_DIR/config" nvim --headless --startuptime "$TMP_STARTUP" '+qa!' >/dev/null 2>&1
  STARTUP_SAMPLES+=("$(awk '/^[0-9]+\.[0-9]+/ { last=$1 } END { print last + 0 }' "$TMP_STARTUP")")
done
STARTUP_MS="$(printf '%s\n' "${STARTUP_SAMPLES[@]}" | sort -n | awk 'NR==3 { print $1 }')"

# Count configured plugins from lazy's loaded config table.
PLUGIN_COUNT="$(XDG_CONFIG_HOME="$ROOT_DIR/config" nvim --headless \
  '+lua io.stdout:write("PLUGIN_COUNT=" .. vim.tbl_count(require("lazy.core.config").plugins) .. string.char(10))' \
  '+qa!' 2>/dev/null | awk -F= '/^PLUGIN_COUNT=/{print $2; exit}')"
PLUGIN_COUNT="${PLUGIN_COUNT:-0}"

echo "METRIC startup_ms=${STARTUP_MS}"
echo "METRIC plugin_count=${PLUGIN_COUNT}"
echo "METRIC config_boot_ok=1"
