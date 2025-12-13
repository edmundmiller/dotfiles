# Taskwarrior aliases for zsh

# Wrapper to auto-detect terminal width for piped output
# When output is piped (to less, grep, AI agents, etc.), taskwarrior can't detect
# terminal width and falls back to defaultwidth (80). This wrapper passes the
# current terminal width via rc.defaultwidth when stdout is not a TTY.
# See: https://www.reddit.com/r/taskwarrior/comments/10sjzzz/
function task() {
    if [[ -t 1 ]]; then
        # stdout is a TTY, taskwarrior can detect width normally
        command task "$@"
    else
        # stdout is piped, pass terminal width explicitly
        local width=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
        command task rc.defaultwidth:$width "$@"
    fi
}

# Task shell with readline support
# From: https://news.ycombinator.com/item?id=3482583
# Note: `task shell` was removed in Taskwarrior 3.x and moved to separate `tasksh` package
alias tsh='rlwrap -i -r -C tasksh tasksh'

# Taskwarrior TUI
alias tt="taskwarrior-tui"

# Quick view - top 10 urgent tasks
alias t="task next limit:10"
