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
  --bind "ctrl-t:change-prompt(tmux> )+reload($SESH list -t)" \
  --bind "ctrl-c:change-prompt(configs> )+reload($SESH list -c)" \
  --bind "ctrl-x:change-prompt(zoxide> )+reload($SCRIPT_DIR/zoxide-list.sh)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload($SCRIPT_DIR/sesh-all.sh)")

# Strip colored dot prefix (• ) added by sesh-all.sh before connecting
SESSION=$(printf '%s' "$SESSION" | sed 's/.*• //')
[ -n "$SESSION" ] && sesh connect "$SESSION"
exit 0
