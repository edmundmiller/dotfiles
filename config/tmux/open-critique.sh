#!/usr/bin/env bash
# Beautiful TUI for reviewing git diffs with syntax highlighting
# https://github.com/remorses/critique

# If uncommitted changes exist, show them; otherwise show last commit
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    exec bunx critique "$@"
else
    exec bunx critique HEAD~1..HEAD "$@"
fi
