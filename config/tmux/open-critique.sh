#!/usr/bin/env bash
# Beautiful TUI for reviewing git diffs with syntax highlighting
# https://github.com/remorses/critique

DEBUG_LOG="/tmp/critique-debug-$(date +%s).log"
OUTPUT_LOG="/tmp/critique-output-$(date +%s).log"

exec 2>>"$DEBUG_LOG"
set -x
set -o pipefail

echo "=== Critique Debug Session $(date) ===" >>"$DEBUG_LOG"

{
    echo "--- Env ---"
    env | grep -E "(TERM|TTY|PATH|SHELL|TMUX|BUN)"
    echo "--- TTY ---"
    tty || true
    [ -t 0 ] && echo "stdin: TTY" || echo "stdin: NOT TTY"
    [ -t 1 ] && echo "stdout: TTY" || echo "stdout: NOT TTY"
    [ -t 2 ] && echo "stderr: TTY" || echo "stderr: NOT TTY"
    echo "--- Critique ---"
    command -v critique || true
    critique --version || true
} >>"$DEBUG_LOG" 2>&1

export GIT_EXTERNAL_DIFF=""

git_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$git_root" ]]; then
    echo "Not in a git repo"
    echo "Press enter to close..."
    read
    exit 1
fi

cd "$git_root" || exit 1

start=$(date +%s)

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    args=()
else
    args=(HEAD~1..HEAD)
fi

echo "--- Run ---" >>"$DEBUG_LOG"
echo "Command: critique ${args[*]} $*" >>"$DEBUG_LOG"

critique "${args[@]}" "$@" 2>&1 | tee "$OUTPUT_LOG"
exitcode=${PIPESTATUS[0]}

end=$(date +%s)
runtime=$((end - start))

echo "Exit code: $exitcode" >>"$DEBUG_LOG"
echo "Runtime: ${runtime}s" >>"$DEBUG_LOG"

if [[ $exitcode -ne 0 || $runtime -lt 1 ]]; then
    echo "Critique exited (status $exitcode, runtime ${runtime}s)"
    echo "Debug log: $DEBUG_LOG"
    echo "Output log: $OUTPUT_LOG"
    echo "Press enter to close..."
    read
fi

exit $exitcode
