#!/usr/bin/env bash
# sesh session picker — no emojis, handles escape gracefully

SESSION=$(sesh list | fzf-tmux -p 80%,70% \
  --no-sort \
  --border-label " sesh " \
  --prompt "> " \
  --header "^a all  ^t tmux  ^c configs  ^x zoxide  ^d kill" \
  --bind "tab:down,btab:up" \
  --bind "ctrl-a:change-prompt(> )+reload(sesh list)" \
  --bind "ctrl-t:change-prompt(tmux> )+reload(sesh list -t)" \
  --bind "ctrl-c:change-prompt(configs> )+reload(sesh list -c)" \
  --bind "ctrl-x:change-prompt(zoxide> )+reload(sesh list -z)" \
  --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload(sesh list)" \
  --preview-window "right:55%" \
  --preview "sesh preview {}")

[ -n "$SESSION" ] && sesh connect "$SESSION"
exit 0
