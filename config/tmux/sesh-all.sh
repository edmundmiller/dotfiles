#!/usr/bin/env bash
# All sesh sources with distinct symbol+color prefixes:
#   magenta ■ tmux sessions  (live/active)
#   yellow  □ config entries (configured)
#   blue    › zoxide dirs    (frecency)
# Filters out the current tmux session and current pane directory.

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
SCRIPT_DIR="${TMUX_HOME:-$(dirname "$0")}"
SESH_BIN="${SESH_BIN:-$(resolve_bin sesh "/opt/homebrew/bin/sesh" "/run/current-system/sw/bin/sesh" "$HOME/.nix-profile/bin/sesh")}"
BASH_BIN="${BASH_BIN:-$(resolve_bin bash "/bin/bash" "/usr/bin/bash" "$HOME/.nix-profile/bin/bash")}"

CURRENT_SESSION=""
CURRENT_DIR=""
if [[ -n "$TMUX_BIN" ]]; then
  CURRENT_SESSION=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null || true)
  CURRENT_DIR=$("$TMUX_BIN" display-message -p '#{pane_current_path}' 2>/dev/null || true)
fi

CURRENT_DIR_SHORT=${CURRENT_DIR/#$HOME/\~}

[[ -n "$SESH_BIN" ]] || exit 0

print_items() {
  local color="$1"
  local current="$2"
  local symbol="$3"
  local line

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "$current" ]] && continue
    printf '\033[%sm%s\033[0m %s\n' "$color" "$symbol" "$line"
  done
}

print_items 35 "$CURRENT_SESSION" '■' < <("$SESH_BIN" list -t)
print_items 33 "$CURRENT_SESSION" '□' < <("$SESH_BIN" list -c)
print_items 34 "$CURRENT_DIR_SHORT" '›' < <("$BASH_BIN" "$SCRIPT_DIR/zoxide-list.sh")

exit 0
