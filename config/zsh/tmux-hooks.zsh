if [[ -n "$TMUX_WINDOW_NAME_SCRIPT" ]]; then
  tmux-window-name-update() {
    ($TMUX_WINDOW_NAME_SCRIPT &) >/dev/null 2>&1
  }
  
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd tmux-window-name-update
fi
