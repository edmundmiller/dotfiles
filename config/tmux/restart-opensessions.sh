#!/usr/bin/env sh

set -eu

OPENSESSIONS_DIR="${OPENSESSIONS_DIR:-$HOME/.local/share/opensessions/current}"
SCRIPTS_DIR="$OPENSESSIONS_DIR/integrations/tmux-plugin/scripts"
HOST="${OPENSESSIONS_HOST:-127.0.0.1}"
PORT="${OPENSESSIONS_PORT:-7391}"
PID_FILE="/tmp/opensessions.pid"

if [ ! -d "$SCRIPTS_DIR" ]; then
  tmux display-message "opensessions: missing scripts at $SCRIPTS_DIR"
  exit 0
fi

# Best-effort graceful shutdown.
curl -s -o /dev/null -X POST "http://${HOST}:${PORT}/shutdown" 2>/dev/null || true

# Kill stale pid if still present.
if [ -f "$PID_FILE" ]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

# If an opensessions server is still bound on the port, force-kill listener pids.
if curl -s -m 1 "http://${HOST}:${PORT}/" 2>/dev/null | grep -q '^opensessions server$'; then
  for pid in $(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true); do
    kill "$pid" 2>/dev/null || true
  done
fi

# Ensure the fresh server is up and current window has sidebar state.
sh "$SCRIPTS_DIR/ensure-sidebar.sh"

ready=0
attempt=0
while [ "$attempt" -lt 30 ]; do
  if curl -s -m 1 "http://${HOST}:${PORT}/" 2>/dev/null | grep -q '^opensessions server$'; then
    ready=1
    break
  fi
  sleep 0.1
  attempt=$((attempt + 1))
done

if [ "$ready" -eq 1 ]; then
  tmux display-message "opensessions: restarted"
else
  tmux display-message "opensessions: restart requested, but server is still unavailable"
fi

