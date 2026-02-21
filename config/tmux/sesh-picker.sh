#!/usr/bin/env bash
# sesh session picker — no emojis, handles escape gracefully

SESH=/opt/homebrew/bin/sesh
ZOXIDE=/opt/homebrew/bin/zoxide
# Top 30 zoxide dirs by frecency, skipping noise
ZOXIDE_CMD="$ZOXIDE query --list | head -30"

SESSION=$($SESH list | fzf-tmux -p 80%,70% \
  --no-sort \
  --border-label " sesh " \
  --prompt "> " \
  --header "^a all  ^t tmux  ^c configs  ^x zoxide  ^d kill" \
  --bind "tab:down,btab:up" \
  --bind "ctrl-a:change-prompt(> )+reload($SESH list)" \
  --bind "ctrl-t:change-prompt(tmux> )+reload($SESH list -t)" \
  --bind "ctrl-c:change-prompt(configs> )+reload($SESH list -c)" \
  --bind "ctrl-x:change-prompt(zoxide> )+reload($ZOXIDE_CMD)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload($SESH list)")

[ -n "$SESSION" ] && sesh connect "$SESSION"
exit 0
