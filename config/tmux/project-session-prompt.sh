#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: project-session-prompt.sh <create|remove>" >&2
}

action="${1:-}"
case "$action" in
  create)
    prompt="Worktree name:"
    ;;
  remove)
    prompt="Remove worktree:"
    ;;
  *)
    usage
    exit 1
    ;;
esac

exec tmux command-prompt -p "$prompt" "run-shell '$TMUX_HOME/project-session.sh $action \"%%\"'"
