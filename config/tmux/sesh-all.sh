#!/usr/bin/env bash
# All sesh sources with distinct symbol+color prefixes:
#   magenta ■ tmux sessions  (live/active)
#   yellow  □ config entries (configured)
#   blue    › zoxide dirs    (frecency)
# Filters out the current tmux session and current pane directory.

resolve_bin() {
  local name="$1"
  shift

  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -x "$candidate" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done

  command -v "$name" 2>/dev/null || true
}

TMUX_BIN="${TMUX_BIN:-$(resolve_bin tmux "/opt/homebrew/bin/tmux" "/run/current-system/sw/bin/tmux" "$HOME/.nix-profile/bin/tmux")}"
SCRIPT_DIR=${TMUX_HOME:-$(dirname "$0")}
SESH_BIN="${SESH_BIN:-$(resolve_bin sesh "/opt/homebrew/bin/sesh" "/run/current-system/sw/bin/sesh" "$HOME/.nix-profile/bin/sesh")}"
CURRENT_SESSION=""
CURRENT_DIR=""
if [[ -n "$TMUX_BIN" ]]; then
  CURRENT_SESSION=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null || true)
  CURRENT_DIR=$("$TMUX_BIN" display-message -p '#{pane_current_path}' 2>/dev/null || true)
fi
# Collapse $HOME to ~ for matching against zoxide/config output
CURRENT_DIR_SHORT=${CURRENT_DIR/#$HOME/\~}

[[ -n "$SESH_BIN" ]] || exit 0

"$SESH_BIN" list -t | grep -vxF "$CURRENT_SESSION" | awk '{printf "\033[35m■\033[0m %s\n", $0}'
"$SESH_BIN" list -c | grep -vxF "$CURRENT_SESSION" | awk '{printf "\033[33m□\033[0m %s\n", $0}'
"$SCRIPT_DIR/zoxide-list.sh" | grep -vxF "$CURRENT_DIR_SHORT" | awk '{printf "\033[34m›\033[0m %s\n", $0}'
