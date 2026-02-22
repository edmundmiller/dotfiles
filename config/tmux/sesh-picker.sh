#!/usr/bin/env bash
# sesh session picker — no emojis, handles escape gracefully

SESH=/opt/homebrew/bin/sesh
SCRIPT_DIR=${TMUX_HOME:-/Users/emiller/.config/tmux}
CUR_SESS=$(tmux display-message -p '#S' 2>/dev/null)
CUR_DIR=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
CUR_DIR_SHORT=${CUR_DIR/#$HOME/\~}

SESSION=$($SCRIPT_DIR/sesh-all.sh | fzf-tmux -p 80%,70% \
  --ansi \
  --no-sort \
  --border-label " sesh " \
  --prompt "> " \
  --header "^a all  ^t tmux  ^c configs  ^x zoxide  ^d kill" \
  --bind "tab:down,btab:up" \
  --bind "ctrl-a:change-prompt(> )+reload($SCRIPT_DIR/sesh-all.sh)" \
  --bind "ctrl-t:change-prompt(tmux> )+reload($SESH list -t | grep -vxF '$CUR_SESS' | awk '{printf \"\\033[35m■\\033[0m %s\\n\", \$0}')" \
  --bind "ctrl-c:change-prompt(configs> )+reload($SESH list -c | grep -vxF '$CUR_SESS' | awk '{printf \"\\033[33m□\\033[0m %s\\n\", \$0}')" \
  --bind "ctrl-x:change-prompt(zoxide> )+reload($SCRIPT_DIR/zoxide-list.sh | grep -vxF '$CUR_DIR_SHORT' | awk '{printf \"\\033[34m›\\033[0m %s\\n\", \$0}')" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload($SCRIPT_DIR/sesh-all.sh)")

# Strip ANSI escape codes, then the symbol prefix
SESSION=$(printf '%s' "$SESSION" | sed 's/\x1b\[[0-9;]*m//g; s/^[■□›] //')
[ -n "$SESSION" ] && $SESH connect "$SESSION"
exit 0
