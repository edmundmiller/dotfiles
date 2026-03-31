# tmux-smart-name is the authoritative naming/title layer.
# It exports TMUX_WINDOW_NAME_SCRIPT for shells running inside tmux.
# When available, refresh smart naming on chpwd so title/window metadata tracks
# the current project or task without requiring manual tmux interaction.
if [[ -n "$TMUX" && -n "$TMUX_WINDOW_NAME_SCRIPT" ]]; then
  tmux-window-name-update() {
    ($TMUX_WINDOW_NAME_SCRIPT &) >/dev/null 2>&1
  }
  
  autoload -Uz add-zsh-hook
  add-zsh-hook -d chpwd tmux-window-name-update 2>/dev/null || true
  add-zsh-hook chpwd tmux-window-name-update
fi
