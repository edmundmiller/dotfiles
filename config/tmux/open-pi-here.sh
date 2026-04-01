#!/usr/bin/env bash

# Launch a new Pi window in the current tmux session, using the current
# pane path but normalizing bare worktree hubs to a usable checkout.

set -euo pipefail

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
PI_BIN="${PI_BIN:-$(resolve_bin pi "/opt/homebrew/bin/pi" "/run/current-system/sw/bin/pi" "$HOME/.nix-profile/bin/pi")}"

current_dir=$($TMUX_BIN display-message -p '#{pane_current_path}' 2>/dev/null || pwd)
resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
[[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"

if [[ -x "$resolver" ]]; then
  safe_cwd=$($resolver "$current_dir") || exit 1
else
  safe_cwd="$current_dir"
fi

if "$TMUX_BIN" display-message -p '#{session_name}' >/dev/null 2>&1; then
  exec "$TMUX_BIN" new-window -c "$safe_cwd" "$PI_BIN"
fi

cd "$safe_cwd"
exec "$PI_BIN"
