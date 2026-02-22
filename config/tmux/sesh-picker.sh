#!/usr/bin/env bash
# sesh session picker — no emojis, handles escape gracefully

SESH=/opt/homebrew/bin/sesh
SCRIPT_DIR=${TMUX_HOME:-/Users/emiller/.config/tmux}

SESSION=$($SCRIPT_DIR/sesh-all.sh | fzf-tmux -p 80%,70% \
  --ansi \
  --no-sort \
  --border-label " sesh " \
  --prompt "> " \
  --header "^a all  ^t tmux  ^c configs  ^x zoxide  ^d kill" \
  --bind "tab:down,btab:up" \
  --bind "ctrl-a:change-prompt(> )+reload($SCRIPT_DIR/sesh-all.sh)" \
  --bind "ctrl-t:change-prompt(tmux> )+reload($SESH list -t | awk '{printf \"\\033[35m▪\\033[0m %s\\n\", \$0}')" \
  --bind "ctrl-c:change-prompt(configs> )+reload($SESH list -c | awk '{printf \"\\033[33m▫\\033[0m %s\\n\", \$0}')" \
  --bind "ctrl-x:change-prompt(zoxide> )+reload($SCRIPT_DIR/zoxide-list.sh | awk '{printf \"\\033[34m›\\033[0m %s\\n\", \$0}')" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload($SCRIPT_DIR/sesh-all.sh)")

# Strip ANSI escape codes, then the symbol prefix
SESSION=$(printf '%s' "$SESSION" | sed 's/\x1b\[[0-9;]*m//g; s/^[▪▫›] //')
# Debug: log what we're connecting to
echo "$(date) raw='$SESSION'" >> /tmp/sesh-debug.log
[ -n "$SESSION" ] && $SESH connect "$SESSION" 2>> /tmp/sesh-debug.log
exit 0
