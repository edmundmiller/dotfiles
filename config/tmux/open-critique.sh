#!/usr/bin/env bash
# Beautiful TUI for reviewing git diffs with syntax highlighting
# https://github.com/edmundmiller/critique

# Ensure bun is in PATH (tmux popup doesn't inherit full shell PATH)
export PATH="$HOME/.bun/bin:$PATH"

# Neutralize difftastic/external diff — critique needs standard git diff output
# (mirrors the GIT_CONFIG_GLOBAL trick in the pi critique extension)
CRITIQUE_GIT_CONFIG="${TMPDIR:-/tmp}/critique-gitconfig"
[[ -f "$CRITIQUE_GIT_CONFIG" ]] || printf '[user]\n  name = critique\n  email = critique@local\n' > "$CRITIQUE_GIT_CONFIG"
export GIT_CONFIG_GLOBAL="$CRITIQUE_GIT_CONFIG"
export GIT_CONFIG_SYSTEM=/dev/null

git_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$git_root" ]]; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read
    exit 1
fi

cd "$git_root" || exit 1

# Pass args through — callers control staged/unstaged:
#   (no args)  → unstaged changes
#   --staged   → staged changes
exec bunx github:edmundmiller/critique "$@"
