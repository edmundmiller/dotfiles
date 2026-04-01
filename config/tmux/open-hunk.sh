#!/usr/bin/env bash

# Hunk review popup launcher.

set -euo pipefail

# Ensure bun is in PATH (tmux popup doesn't inherit full shell PATH)
export PATH="$HOME/.bun/bin:$PATH"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read -r
    exit 1
fi

resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
[[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"
if [[ -x "$resolver" ]]; then
    git_root=$($resolver ".") || {
        echo "Not in a usable checkout"
        echo "Press enter to close..."
        read -r
        exit 1
    }
else
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
fi

if [[ -z "$git_root" ]]; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read -r
    exit 1
fi

cd "$git_root" || exit 1

if command -v hunk >/dev/null 2>&1; then
    exec hunk diff "$@"
fi

exec bunx hunkdiff diff "$@"
