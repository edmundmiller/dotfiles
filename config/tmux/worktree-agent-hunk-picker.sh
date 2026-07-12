#!/usr/bin/env bash

set -euo pipefail

resolve_bin() {
  local name="$1"
  shift
  if command -v "$name" >/dev/null 2>&1; then command -v "$name"; return; fi
  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
  done
  return 1
}

resolve_base64() {
  local candidate
  for candidate in /opt/homebrew/opt/coreutils/libexec/gnubin/base64 /run/current-system/sw/bin/base64 "$HOME/.nix-profile/bin/base64" "$(command -v base64 2>/dev/null || true)"; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    if printf '' | "$candidate" --decode >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

resolve_helper() {
  local helper="$1" candidate
  candidate="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/$helper"
  [[ -x "$candidate" ]] || candidate="$HOME/.config/dotfiles/bin/$helper"
  [[ -x "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

encode() { printf '%s' "$1" | "$BASE64_BIN" | tr -d '\n'; }
decode() { printf '%s' "$1" | "$BASE64_BIN" --decode; }
label_for() {
  case "$1" in omp) printf OMP ;; pi) printf Pi ;; hermes) printf Hermes ;; opencode) printf OpenCode ;; esac
}
contains_worktree() {
  local wanted="$1" path
  for path in "${worktrees[@]}"; do [[ "$path" == "$wanted" ]] && return 0; done
  return 1
}

TMUX_BIN="${TMUX_BIN:-$(resolve_bin tmux /opt/homebrew/bin/tmux /run/current-system/sw/bin/tmux "$HOME/.nix-profile/bin/tmux")}" 
BASH_BIN="${BASH_BIN:-$(resolve_bin bash /bin/bash /usr/bin/bash "$HOME/.nix-profile/bin/bash")}" 
BUN_BIN="${BUN_BIN:-$(resolve_bin bun "$HOME/.bun/bin/bun" /opt/homebrew/bin/bun /run/current-system/sw/bin/bun)}"
FZF_TMUX_BIN="${FZF_TMUX_BIN:-$(resolve_bin fzf-tmux /opt/homebrew/bin/fzf-tmux /run/current-system/sw/bin/fzf-tmux "$HOME/.nix-profile/bin/fzf-tmux")}" 
BASE64_BIN="${BASE64_BIN:-$(resolve_base64)}"
if [[ -z "${OPENCODE_BIN+x}" ]]; then
  OPENCODE_BIN=$(resolve_bin opencode /opt/homebrew/bin/opencode /run/current-system/sw/bin/opencode "$HOME/.nix-profile/bin/opencode" || true)
fi
SCRIPT_DIR="${TMUX_HOME:-$HOME/.config/tmux}"
collector="${AGENT_HUNK_SESSIONS:-$SCRIPT_DIR/agent-hunk-sessions.ts}"
git_worktree_cwd=$(resolve_helper git-worktree-cwd)
tmux_project_root=$(resolve_helper tmux-project-root)

current_dir=$("$TMUX_BIN" display-message -p '#{pane_current_path}' 2>/dev/null || pwd -P)
safe_cwd=$("$git_worktree_cwd" "$current_dir")
checkout_root=$("$tmux_project_root" "$safe_cwd")
worktrees=()
while IFS= read -r -d '' field; do
  if [[ "$field" == worktree\ * ]]; then
    path=$("$git_worktree_cwd" "${field#worktree }")
    worktrees+=("$path")
  fi
done < <(git -C "$checkout_root" worktree list --porcelain -z)
[[ ${#worktrees[@]} -gt 0 ]] || worktrees+=("$safe_cwd")

rows=$(mktemp "${TMPDIR:-/tmp}/agent-hunk-picker.XXXXXX")
trap 'rm -f "$rows"' EXIT
repo_name=$(basename -- "$safe_cwd")
for runtime in omp pi hermes; do
  label=$(label_for "$runtime")
  printf -- '-\tNew %s + Hunk…\t%s\t%s\tnew\t%s\t\t%s\n' "$label" "$repo_name" "$label" "$runtime" "$(encode "$safe_cwd")" >> "$rows"
done
if [[ -n "$OPENCODE_BIN" ]] && "$OPENCODE_BIN" service status >/dev/null 2>&1; then
  printf -- '-\tNew OpenCode + Hunk…\t%s\tOpenCode\tnew\topencode\t\t%s\n' "$repo_name" "$(encode "$safe_cwd")" >> "$rows"
fi

while IFS='|' read -r window_id window_name worktree runtime token; do
  [[ -n "$window_id" ]] || continue
  canonical=""
  if [[ -n "$worktree" ]]; then
    canonical=$("$git_worktree_cwd" "$worktree" 2>/dev/null || true)
    contains_worktree "$canonical" || continue
  fi
  live=0
  while IFS='|' read -r role dead command cwd; do
    [[ "$dead" == 0 ]] || continue
    if [[ "$role" == agent ]]; then live=1; break; fi
    if [[ -z "$role" && "$command" == hermes ]]; then
      pane_cwd=$("$git_worktree_cwd" "$cwd" 2>/dev/null || true)
      contains_worktree "$pane_cwd" || continue
      live=1; canonical="$pane_cwd"; runtime=hermes; break
    fi
  done < <("$TMUX_BIN" list-panes -t "$window_id" -F '#{@paired_role}|#{pane_dead}|#{pane_current_command}|#{pane_current_path}' 2>/dev/null || true)
  [[ "$live" == 1 && -n "$canonical" ]] || continue
  label=$(label_for "$runtime")
  [[ -n "$label" ]] || continue
  printf -- '-\tActive %s\t%s\t%s\tactive\t%s\t%s\t%s\n' "${window_name:-$label}" "$(basename -- "$canonical")" "$label" "$runtime" "$(encode "$window_id")" "$(encode "$canonical")" >> "$rows"
done < <("$TMUX_BIN" list-windows -a -F '#{window_id}|#{window_name}|#{@paired_worktree_path}|#{@paired_agent_runtime}|#{@paired_agent_session_id}' 2>/dev/null || true)

collector_args=("$collector" list)
for path in "${worktrees[@]}"; do collector_args+=(--worktree "$path"); done
collector_args+=(--pi-agent-dir "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" --omp-agent-dir "$HOME/.omp/agent" --hermes-db "${HERMES_HOME:-$HOME/.hermes}/state.db")
[[ -z "$OPENCODE_BIN" ]] || collector_args+=(--opencode-bin "$OPENCODE_BIN")
"$BUN_BIN" "${collector_args[@]}" >> "$rows"

selection=$("$FZF_TMUX_BIN" -p 85%,75% --with-nth=1,2,3,4 < "$rows" || true)
[[ -n "$selection" ]] || exit 0
IFS=$'\t' read -r _ _ _ _ action runtime token_encoded path_encoded <<< "$selection"
case "$action" in
  new)
    exec "$BASH_BIN" "$SCRIPT_DIR/worktree-agent-hunk-prompt.sh" "$runtime"
    ;;
  active)
    window_id=$(decode "$token_encoded")
    worktree=$(decode "$path_encoded")
    exec "$BASH_BIN" "$SCRIPT_DIR/worktree-agent-hunk.sh" active "$window_id" "$worktree"
    ;;
  resume)
    token=$(decode "$token_encoded")
    worktree=$(decode "$path_encoded")
    exec "$BASH_BIN" "$SCRIPT_DIR/worktree-agent-hunk.sh" resume "$runtime" "$token" "$worktree"
    ;;
  *) exit 1 ;;
esac
