#!/usr/bin/env sh

set -eu

OPENSESSIONS_DIR="${OPENSESSIONS_DIR:-$HOME/.local/share/opensessions/current}"
PLUGIN_ENTRY="$OPENSESSIONS_DIR/opensessions.tmux"
SCRIPTS_DIR="$OPENSESSIONS_DIR/integrations/tmux-plugin/scripts"
HOST="${OPENSESSIONS_HOST:-127.0.0.1}"
PORT="${OPENSESSIONS_PORT:-7391}"
PID_FILE="/tmp/opensessions.pid"

ok() {
  printf '✅ %s\n' "$*"
}

warn() {
  printf '⚠️  %s\n' "$*"
}

header() {
  printf '\n== %s ==\n' "$*"
}

printf 'opensessions doctor\n'
printf 'timestamp: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"

header "runtime"
if command -v bun >/dev/null 2>&1; then
  ok "bun: $(bun --version)"
else
  warn "bun not found on PATH"
fi

if command -v curl >/dev/null 2>&1; then
  ok "curl: available"
else
  warn "curl not found on PATH"
fi

if [ -f "$PLUGIN_ENTRY" ]; then
  ok "plugin entry: $PLUGIN_ENTRY"
else
  warn "missing plugin entry: $PLUGIN_ENTRY"
fi

if [ -d "$SCRIPTS_DIR" ]; then
  ok "plugin scripts: $SCRIPTS_DIR"
else
  warn "missing plugin scripts: $SCRIPTS_DIR"
fi

header "server"
if curl -s -m 1 "http://${HOST}:${PORT}/" 2>/dev/null | grep -q '^opensessions server$'; then
  ok "server responds on http://${HOST}:${PORT}"
else
  warn "server not responding on http://${HOST}:${PORT}"
fi

if [ -f "$PID_FILE" ]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
    ok "pid file: $PID_FILE (pid $pid alive)"
    ps -p "$pid" -o command= 2>/dev/null | sed 's/^/   /'
  else
    warn "pid file exists but process is not alive: $PID_FILE"
  fi
else
  warn "pid file missing: $PID_FILE"
fi

header "tmux env"
for v in OPENSESSIONS_DIR OPENSESSIONS_HOST OPENSESSIONS_PORT OPENSESSIONS_PATH_PREFIX BUN_PATH; do
  value="$(tmux show-environment -g "$v" 2>/dev/null | cut -d= -f2- || true)"
  if [ -n "$value" ]; then
    ok "$v=$value"
  else
    warn "$v is not set"
  fi
done

header "keybindings"
if tmux list-keys -T opensessions >/dev/null 2>&1; then
  ok "opensessions command table is present"
  tmux list-keys -T opensessions | sed -n '1,12p'
else
  warn "opensessions command table not found"
fi

printf '\nSuggestions:\n'
printf '  - restart sidebar server: prefix Space o r\n'
printf '  - open config JSON:       prefix Space o o\n'
printf '  - focus sidebar:          prefix Space o s\n'
printf '\nPress Enter to close...'
read -r _

