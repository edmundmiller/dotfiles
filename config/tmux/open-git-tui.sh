#!/usr/bin/env bash
# Smart launcher for git TUIs based on VCS type.
# Used by tmux popup binding (prefix + g).

set -euo pipefail

resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
[[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"
if [[ -x "$resolver" ]]; then
  safe_cwd=$($resolver ".") || {
    echo "Not in a usable checkout"
    echo "Press enter to close..."
    read -r
    exit 1
  }
  cd "$safe_cwd"
fi

# Detect VCS type (priority: jj > git > fallback)
if [ -d ".jj" ]; then
  exec jjui
elif [ -d ".git" ] || git rev-parse --git-dir >/dev/null 2>&1; then
  exec gitu
else
  # Fallback to gitu if no VCS detected
  exec gitu
fi
