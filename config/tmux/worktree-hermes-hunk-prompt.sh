#!/usr/bin/env bash

set -euo pipefail

exec tmux command-prompt -p "Branch/task work window name:" "run-shell 'bash \"$TMUX_HOME/worktree-hermes-hunk.sh\" \"%%\"'"
