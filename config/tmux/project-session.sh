#!/usr/bin/env bash

# Project/worktree helper for tmux UI entry points.
# Uses the current pane path, then delegates to the existing tmproj/tw/twd helpers.

set -euo pipefail

usage() {
  echo "Usage: project-session.sh <attach|create|remove> [name]" >&2
}

resolve_bin() {
  local name="$1"
  shift

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -x "$candidate" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done

  return 1
}

TMUX_BIN="${TMUX_BIN:-$(resolve_bin tmux "/opt/homebrew/bin/tmux" "/run/current-system/sw/bin/tmux" "$HOME/.nix-profile/bin/tmux")}"
TMPROJ_BIN="${TMPROJ_BIN:-$(resolve_bin tmproj "/opt/homebrew/bin/tmproj" "/run/current-system/sw/bin/tmproj" "$HOME/.nix-profile/bin/tmproj" "$HOME/.config/dotfiles/bin/tmproj")}"
TW_BIN="${TW_BIN:-$(resolve_bin tw "/opt/homebrew/bin/tw" "/run/current-system/sw/bin/tw" "$HOME/.nix-profile/bin/tw" "$HOME/.config/dotfiles/bin/tw")}"
TWD_BIN="${TWD_BIN:-$(resolve_bin twd "/opt/homebrew/bin/twd" "/run/current-system/sw/bin/twd" "$HOME/.nix-profile/bin/twd" "$HOME/.config/dotfiles/bin/twd")}"

current_dir=$($TMUX_BIN display-message -p '#{pane_current_path}' 2>/dev/null || true)
if [[ -z "$current_dir" ]]; then
  echo "project-session: unable to determine current pane path" >&2
  exit 1
fi

action="${1:-}"
case "$action" in
  attach)
    exec "$TMPROJ_BIN" "$current_dir"
    ;;
  create)
    name="${2:-}"
    [[ -n "$name" ]] || {
      usage
      exit 1
    }
    cd "$current_dir"
    exec "$TW_BIN" "$name"
    ;;
  remove)
    name="${2:-}"
    [[ -n "$name" ]] || {
      usage
      exit 1
    }
    cd "$current_dir"
    exec "$TWD_BIN" "$name"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
