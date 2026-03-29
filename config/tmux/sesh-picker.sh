#!/usr/bin/env bash
# sesh session picker — no emojis, handles escape gracefully

resolve_bin() {
  local name="$1"
  shift

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -x "$candidate" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done

  return 0
}

TMUX_BIN="${TMUX_BIN:-$(resolve_bin tmux "/opt/homebrew/bin/tmux" "/run/current-system/sw/bin/tmux" "$HOME/.nix-profile/bin/tmux")}"
SESH_BIN="${SESH_BIN:-$(resolve_bin sesh "/opt/homebrew/bin/sesh" "/run/current-system/sw/bin/sesh" "$HOME/.nix-profile/bin/sesh")}"
FZF_TMUX_BIN="${FZF_TMUX_BIN:-$(resolve_bin fzf-tmux "/opt/homebrew/bin/fzf-tmux" "/run/current-system/sw/bin/fzf-tmux" "$HOME/.nix-profile/bin/fzf-tmux")}"
SCRIPT_DIR=${TMUX_HOME:-$HOME/.config/tmux}
CUR_SESS=""
CUR_DIR=""
if [[ -n "$TMUX_BIN" ]]; then
  CUR_SESS=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null || true)
  CUR_DIR=$("$TMUX_BIN" display-message -p '#{pane_current_path}' 2>/dev/null || true)
fi
CUR_DIR_SHORT=${CUR_DIR/#$HOME/\~}

tmux_message() {
  local message="$1"
  if [[ -n "$TMUX_BIN" ]]; then
    "$TMUX_BIN" display-message "$message"
  else
    printf '%s\n' "$message" >&2
  fi
}

[[ -n "$SESH_BIN" ]] || {
  tmux_message "sesh-picker: sesh not found"
  exit 1
}

[[ -n "$FZF_TMUX_BIN" ]] || {
  tmux_message "sesh-picker: fzf-tmux not found"
  exit 1
}

export SESH_BIN

SESSION=$(
  bash "$SCRIPT_DIR/sesh-all.sh" | "$FZF_TMUX_BIN" -p 80%,70% \
    --ansi \
    --no-sort \
    --border-label " sesh " \
    --prompt "> " \
    --header "^a all  ^t tmux  ^c configs  ^x zoxide  ^d kill" \
    --bind "tab:down,btab:up" \
    --bind "ctrl-a:change-prompt(> )+reload(bash $SCRIPT_DIR/sesh-all.sh)" \
    --bind "ctrl-t:change-prompt(tmux> )+reload($SESH_BIN list -t | grep -vxF '$CUR_SESS' | awk '{printf \"\\033[35m■\\033[0m %s\\n\", \$0}')" \
    --bind "ctrl-c:change-prompt(configs> )+reload($SESH_BIN list -c | grep -vxF '$CUR_SESS' | awk '{printf \"\\033[33m□\\033[0m %s\\n\", \$0}')" \
    --bind "ctrl-x:change-prompt(zoxide> )+reload(bash $SCRIPT_DIR/zoxide-list.sh | grep -vxF '$CUR_DIR_SHORT' | awk '{printf \"\\033[34m›\\033[0m %s\\n\", \$0}')" \
    --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(> )+reload(bash $SCRIPT_DIR/sesh-all.sh)"
)

# Strip ANSI escape codes, then the symbol prefix
SESSION=$(printf '%s' "$SESSION" | sed 's/\x1b\[[0-9;]*m//g; s/^[■□›] //')
[ -n "$SESSION" ] && "$SESH_BIN" connect "$SESSION"
exit 0
