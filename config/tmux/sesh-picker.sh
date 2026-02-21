#!/usr/bin/env bash
# sesh session picker — no emojis, handles escape gracefully

SESH=/opt/homebrew/bin/sesh

SESSION=$($SESH list | fzf-tmux -p 80%,70% \
  --no-sort \
  --border-label " sesh " \
  --prompt "> " \
  --header "^a all  ^t tmux  ^c configs  ^x zoxide  ^d kill" \
  --bind "tab:down,btab:up" \
  --bind "ctrl-a:change-prompt(> )+reload($SESH list)" \
  --bind "ctrl-t:change-prompt(tmux> )+reload($SESH list -t)" \
  --bind "ctrl-c:change-prompt(configs> )+reload($SESH list -c)" \
  --bind "ctrl-x:change-prompt(zoxide> )+reload($SESH list -z)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload($SESH list)" \
  --preview-window "right:55%" \
  --preview "$SESH preview {}")

[ -n "$SESSION" ] && sesh connect "$SESSION"
exit 0
