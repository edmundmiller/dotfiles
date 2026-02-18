#!/usr/bin/env bash
# Beautiful TUI for reviewing git diffs with syntax highlighting
# https://github.com/remorses/critique

# Ensure bun global bin is in PATH (tmux popup doesn't inherit full shell PATH)
export PATH="$HOME/.bun/bin:$PATH"

# Force git to use built-in diff (critique needs standard git diff output)
export GIT_EXTERNAL_DIFF=""

git_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$git_root" ]]; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read
    exit 1
fi

cd "$git_root" || exit 1

# If uncommitted changes exist, show them; otherwise show last commit
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    exec critique --agent pi "$@"
else
    exec critique HEAD~1..HEAD --agent pi "$@"
fi
