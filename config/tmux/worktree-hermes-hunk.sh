#!/usr/bin/env bash

# Create a sibling git worktree, open/attach its canonical tmux session,
# then open a review work window:
#   left   - opensessions sidebar (if available)
#   middle - hermes
#   right  - hunk diff

set -euo pipefail

usage() {
  echo "Usage: worktree-hermes-hunk.sh <name>" >&2
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

resolve_dotfiles_helper() {
  local helper="$1"
  local candidate="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/$helper"
  [[ -x "$candidate" ]] || candidate="$HOME/.config/dotfiles/bin/$helper"
  [[ -x "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

requested_name="${1:-}"
if [[ -z "$requested_name" ]]; then
  usage
  exit 1
fi

TMUX_BIN="${TMUX_BIN:-$(resolve_bin tmux "/opt/homebrew/bin/tmux" "/run/current-system/sw/bin/tmux" "$HOME/.nix-profile/bin/tmux")}"
HERMES_BIN="${HERMES_BIN:-$(resolve_bin hermes "/opt/homebrew/bin/hermes" "/run/current-system/sw/bin/hermes" "$HOME/.nix-profile/bin/hermes")}"

if [[ -z "${TMUX:-}" ]]; then
  echo "worktree-hermes-hunk: must be run from inside tmux" >&2
  exit 1
fi

git_worktree_cwd="$(resolve_dotfiles_helper git-worktree-cwd)"
tmux_project_root="$(resolve_dotfiles_helper tmux-project-root)"
tmux_project_name="$(resolve_dotfiles_helper tmux-project-name)"
tmux_lib_path="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/tmux-lib.sh"
[[ -f "$tmux_lib_path" ]] || tmux_lib_path="$HOME/.config/dotfiles/bin/tmux-lib.sh"

if [[ ! -f "$tmux_lib_path" ]]; then
  echo "worktree-hermes-hunk: missing helper: $tmux_lib_path" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$tmux_lib_path"

current_dir="$($TMUX_BIN display-message -p '#{pane_current_path}' 2>/dev/null || pwd -P)"
safe_cwd="$($git_worktree_cwd "$current_dir")"
checkout_root="$($tmux_project_root "$safe_cwd")"

worktree_path="$(create_sibling_worktree "$checkout_root" "$requested_name")"
window_name="$(sanitize_component "$requested_name")"
[[ -n "$window_name" ]] || window_name="worktree"

session_name="$($tmux_project_name "$checkout_root")"

if $TMUX_BIN has-session -t "$session_name" 2>/dev/null; then
  window_id="$($TMUX_BIN new-window -d -P -F '#{window_id}' -t "${session_name}:" -n "$window_name" -c "$worktree_path" "$HERMES_BIN")"
else
  window_id="$($TMUX_BIN new-session -d -P -F '#{window_id}' -s "$session_name" -n "$window_name" -c "$worktree_path" "$HERMES_BIN")"
fi

$TMUX_BIN switch-client -t "$session_name"
$TMUX_BIN select-window -t "$window_id"

# Ensure opensessions sidebar exists for this window when integration is available.
opensessions_ensure="${OPENSESSIONS_DIR:-$HOME/.local/share/opensessions/current}/integrations/tmux-plugin/scripts/ensure-sidebar.sh"
if [[ -x "$opensessions_ensure" ]]; then
  sh "$opensessions_ensure" >/dev/null 2>&1 || true
fi

hermes_pane="$($TMUX_BIN list-panes -t "$window_id" -F '#{pane_id} #{pane_title}' | awk '$2 != "opensessions-sidebar" { print $1; exit }')"
if [[ -z "$hermes_pane" ]]; then
  hermes_pane="$($TMUX_BIN display-message -p -t "$window_id" '#{pane_id}')"
fi

hunk_launcher="${TMUX_HOME:-$HOME/.config/tmux}/open-hunk.sh"
$TMUX_BIN split-window -h -p 50 -t "$hermes_pane" -c "$worktree_path" "$hunk_launcher"
$TMUX_BIN select-pane -t "$hermes_pane"

$TMUX_BIN display-message "work window ready: session=$session_name window=$window_name"
