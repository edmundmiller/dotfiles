#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo 'Usage: worktree-agent-hunk-prompt.sh <omp|pi|hermes|opencode>' >&2
}

valid_runtime() {
  case "$1" in omp|pi|hermes|opencode) return 0 ;; *) return 1 ;; esac
}

quote_command() {
  local arg quoted command=""
  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    command+="${command:+ }$quoted"
  done
  printf '%s\n' "$command"
}

TMUX_BIN="${TMUX_BIN:-tmux}"
BASH_BIN="${BASH_BIN:-bash}"

if [[ "${1:-}" == --read ]]; then
  runtime="${2:-}"
  valid_runtime "$runtime" || { usage; exit 1; }
  printf 'Branch/task work window name: '
  IFS= read -r name || exit 0
  [[ -n "$name" ]] || exit 0
  exec "$BASH_BIN" "${TMUX_HOME:-$HOME/.config/tmux}/worktree-agent-hunk.sh" new "$runtime" "$name"
fi

runtime="${1:-}"
valid_runtime "$runtime" || { usage; exit 1; }
command=$(quote_command "$BASH_BIN" "$0" --read "$runtime")
exec "$TMUX_BIN" display-popup -E -T 'Agent + Hunk worktree' -w 70 -h 5 "$command"
