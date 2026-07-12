#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: worktree-agent-hunk.sh new <runtime> <name> | active <window-id> <worktree> | resume <runtime> <session-token> <worktree>" >&2
}

resolve_bin() {
  local name="$1"
  shift
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return
  fi
  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
  done
  return 1
}

resolve_helper() {
  local helper="$1" candidate
  candidate="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/$helper"
  [[ -x "$candidate" || -f "$candidate" ]] || candidate="$HOME/.config/dotfiles/bin/$helper"
  [[ -x "$candidate" || -f "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

quote_command() {
  local arg quoted command=""
  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    command+="${command:+ }$quoted"
  done
  printf '%s\n' "$command"
}

runtime_bin() {
  local runtime="$1" override
  case "$runtime" in
    omp) override="${OMP_BIN:-}" ;;
    pi) override="${PI_BIN:-}" ;;
    hermes) override="${HERMES_BIN:-}" ;;
    opencode) override="${OPENCODE_BIN:-}" ;;
    *) return 1 ;;
  esac
  [[ -z "$override" ]] || { printf '%s\n' "$override"; return; }
  resolve_bin "$runtime" "/opt/homebrew/bin/$runtime" "/run/current-system/sw/bin/$runtime" "$HOME/.nix-profile/bin/$runtime"
}

canonicalize() {
  "$git_worktree_cwd" "$1"
}

focus_window() {
  local window_id="$1" session_id
  session_id=$("$TMUX_BIN" display-message -p -t "$window_id" '#{session_id}')
  "$TMUX_BIN" switch-client -t "$session_id"
  "$TMUX_BIN" select-window -t "$window_id"
}

list_panes() {
  "$TMUX_BIN" list-panes -t "$1" -F '#{pane_id}|#{@paired_role}|#{pane_dead}|#{pane_current_command}|#{pane_current_path}' 2>/dev/null || true
}

find_pane() {
  local window_id="$1" wanted="$2" pane role dead command path
  while IFS='|' read -r pane role dead command path; do
    [[ -n "$pane" ]] || continue
    if [[ "$role" == "$wanted" || ( "$wanted" == hunk && "$command" == hunk ) ]]; then
      printf '%s|%s\n' "$pane" "$dead"
      return
    fi
  done < <(list_panes "$window_id")
}

stamp_window() {
  local window_id="$1" worktree="$2" runtime="$3" token="${4:-}"
  "$TMUX_BIN" set-option -w -t "$window_id" @paired_worktree_path "$worktree"
  "$TMUX_BIN" set-option -w -t "$window_id" @paired_agent_runtime "$runtime"
  [[ -z "$token" ]] || "$TMUX_BIN" set-option -w -t "$window_id" @paired_agent_session_id "$token"
}

stamp_pane() {
  local pane="$1" role="$2" title="$3"
  "$TMUX_BIN" set-option -p -t "$pane" @paired_role "$role"
  "$TMUX_BIN" select-pane -t "$pane" -T "$title"
}

hunk_command() {
  quote_command "$hunk_launcher" --resume
}

repair_hunk() {
  local window_id="$1" worktree="$2" agent_pane="$3" found pane dead command
  found=$(find_pane "$window_id" hunk || true)
  if [[ -n "$found" ]]; then
    IFS='|' read -r pane dead <<< "$found"
    if [[ "$dead" == 1 ]]; then
      command=$(hunk_command)
      "$TMUX_BIN" respawn-pane -k -c "$worktree" -t "$pane" "$command"
    fi
  else
    command=$(hunk_command)
    pane=$("$TMUX_BIN" split-window -d -h -p 50 -P -F '#{pane_id}' -t "$agent_pane" -c "$worktree" "$command")
  fi
  stamp_pane "$pane" hunk hunk-review
}

runtime_command() {
  local action="$1" runtime="$2" token="${3:-}" worktree="$4" bin
  bin=$(runtime_bin "$runtime")
  if [[ "$action" == new ]]; then
    quote_command "$bin"
    return
  fi
  case "$runtime" in
    omp) quote_command "$bin" --cwd "$worktree" --resume "$token" ;;
    pi) quote_command "$bin" --session "$token" ;;
    hermes) quote_command "$bin" --resume "$token" ;;
    opencode) quote_command "$bin" --session "$token" "$worktree" ;;
  esac
}

create_window() {
  local session_name="$1" window_name="$2" worktree="$3" command="$4" window_id
  if "$TMUX_BIN" has-session -t "$session_name" 2>/dev/null; then
    window_id=$("$TMUX_BIN" new-window -d -P -F '#{window_id}' -t "${session_name}:" -n "$window_name" -c "$worktree" "$command")
  else
    window_id=$("$TMUX_BIN" new-session -d -P -F '#{window_id}' -s "$session_name" -n "$window_name" -c "$worktree" "$command")
  fi
  printf '%s\n' "$window_id"
}

find_exact_window() {
  local worktree="$1" runtime="$2" token="$3" window path row_runtime row_token
  while IFS='|' read -r window path row_runtime row_token; do
    [[ "$path" == "$worktree" && "$row_runtime" == "$runtime" && "$row_token" == "$token" ]] && { printf '%s\n' "$window"; return; }
  done < <("$TMUX_BIN" list-windows -a -F '#{window_id}|#{@paired_worktree_path}|#{@paired_agent_runtime}|#{@paired_agent_session_id}' 2>/dev/null || true)
}

has_worktree_collision() {
  local worktree="$1" window path runtime token pane role dead command cwd
  while IFS='|' read -r window path runtime token; do
    [[ "$path" == "$worktree" || -z "$path" ]] || continue
    while IFS='|' read -r pane role dead command cwd; do
      [[ "$dead" == 0 && ( "$role" == agent || -z "$role" ) ]] || continue
      [[ "$path" == "$worktree" || "$cwd" == "$worktree" ]] && return 0
    done < <(list_panes "$window")
  done < <("$TMUX_BIN" list-windows -a -F '#{window_id}|#{@paired_worktree_path}|#{@paired_agent_runtime}|#{@paired_agent_session_id}' 2>/dev/null || true)
  return 1
}

adopt_legacy_hermes() {
  local window_id="$1" worktree="$2" pane role dead command cwd
  while IFS='|' read -r pane role dead command cwd; do
    if [[ -z "$role" && "$dead" == 0 && "$command" == hermes && "$cwd" == "$worktree" ]]; then
      stamp_window "$window_id" "$worktree" hermes
      stamp_pane "$pane" agent hermes-agent
      printf '%s\n' "$pane"
      return
    fi
  done < <(list_panes "$window_id")
}

TMUX_BIN="${TMUX_BIN:-$(resolve_bin tmux /opt/homebrew/bin/tmux /run/current-system/sw/bin/tmux "$HOME/.nix-profile/bin/tmux")}" 
action="${1:-}"
case "$action" in new|active|resume) ;; *) usage; exit 1 ;; esac
[[ -n "${TMUX:-}" ]] || { echo 'worktree-agent-hunk: must be run from inside tmux' >&2; exit 1; }

git_worktree_cwd=$(resolve_helper git-worktree-cwd)
tmux_project_root=$(resolve_helper tmux-project-root)
tmux_project_name=$(resolve_helper tmux-project-name)
tmux_lib_path=$(resolve_helper tmux-lib.sh)
# shellcheck source=/dev/null
source "$tmux_lib_path"
hunk_launcher="${TMUX_HOME:-$HOME/.config/tmux}/open-hunk.sh"

if [[ "$action" == active ]]; then
  [[ $# == 3 ]] || { usage; exit 1; }
  window_id="$2"
  worktree=$(canonicalize "$3")
  found=$(find_pane "$window_id" agent || true)
  if [[ -z "$found" ]]; then
    agent_pane=$(adopt_legacy_hermes "$window_id" "$worktree" || true)
  else
    IFS='|' read -r agent_pane agent_dead <<< "$found"
    [[ "$agent_dead" == 0 ]] || { echo 'worktree-agent-hunk: active agent pane is dead' >&2; exit 1; }
  fi
  [[ -n "${agent_pane:-}" ]] || { echo 'worktree-agent-hunk: no live agent pane' >&2; exit 1; }
  repair_hunk "$window_id" "$worktree" "$agent_pane"
  focus_window "$window_id"
  exit 0
fi

runtime="${2:-}"
runtime_bin "$runtime" >/dev/null || { usage; exit 1; }

if [[ "$action" == new ]]; then
  [[ $# == 3 ]] || { usage; exit 1; }
  requested_name="$3"
  current_dir=$("$TMUX_BIN" display-message -p '#{pane_current_path}' 2>/dev/null || pwd -P)
  safe_cwd=$(canonicalize "$current_dir")
  checkout_root=$("$tmux_project_root" "$safe_cwd")
  worktree=$(create_sibling_worktree "$checkout_root" "$requested_name")
  window_name=$(sanitize_component "$requested_name")
  [[ -n "$window_name" ]] || window_name=worktree
  token=""
else
  [[ $# == 4 ]] || { usage; exit 1; }
  token="$3"
  worktree=$(canonicalize "$4")
  checkout_root=$("$tmux_project_root" "$worktree")
  window_name=$(basename -- "$worktree")
  exact=$(find_exact_window "$worktree" "$runtime" "$token" || true)
  if [[ -n "$exact" ]]; then
    found=$(find_pane "$exact" agent || true)
    if [[ -n "$found" ]]; then
      IFS='|' read -r agent_pane agent_dead <<< "$found"
      if [[ "$agent_dead" == 1 ]]; then
        command=$(runtime_command resume "$runtime" "$token" "$worktree")
        "$TMUX_BIN" respawn-pane -k -c "$worktree" -t "$agent_pane" "$command"
      fi
    else
      command=$(runtime_command resume "$runtime" "$token" "$worktree")
      agent_pane=$("$TMUX_BIN" split-window -d -P -F '#{pane_id}' -t "$exact" -c "$worktree" "$command")
    fi
    stamp_pane "$agent_pane" agent "$runtime-agent"
    repair_hunk "$exact" "$worktree" "$agent_pane"
    focus_window "$exact"
    exit 0
  fi
  if has_worktree_collision "$worktree"; then
    SHA256SUM_BIN="${SHA256SUM_BIN:-$(resolve_bin sha256sum /opt/homebrew/bin/sha256sum /run/current-system/sw/bin/sha256sum "$HOME/.nix-profile/bin/sha256sum")}" 
    suffix=$(printf '%s' "$token" | "$SHA256SUM_BIN")
    window_name="${window_name}-${runtime}-${suffix:0:8}"
  fi
fi

session_name=$("$tmux_project_name" "$checkout_root")
command=$(runtime_command "$action" "$runtime" "$token" "$worktree")
window_id=$(create_window "$session_name" "$window_name" "$worktree" "$command")
agent_pane=$("$TMUX_BIN" display-message -p -t "$window_id" '#{pane_id}')
stamp_window "$window_id" "$worktree" "$runtime" "$token"
stamp_pane "$agent_pane" agent "$runtime-agent"

opensessions_ensure="${OPENSESSIONS_DIR:-$HOME/.local/share/opensessions/current}/integrations/tmux-plugin/scripts/ensure-sidebar.sh"
[[ ! -x "$opensessions_ensure" ]] || sh "$opensessions_ensure" >/dev/null 2>&1 || true
repair_hunk "$window_id" "$worktree" "$agent_pane"
"$TMUX_BIN" select-pane -t "$agent_pane"
focus_window "$window_id"
"$TMUX_BIN" display-message "work window ready: session=$session_name window=$window_name"
