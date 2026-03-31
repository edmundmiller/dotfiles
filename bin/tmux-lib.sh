#!/usr/bin/env bash
# Shared tmux/worktree shell helpers.

sanitize_component() {
  local value="$1"
  value=$(printf '%s' "$value" | sed -E 's/[^[:alnum:]_-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  printf '%s\n' "$value"
}

resolve_repo_stem() {
  local checkout_root="$1"
  local remote_url=""
  local remote_base=""
  local common_dir=""
  local common_parent=""
  local current_base

  current_base=$(basename -- "$checkout_root")

  if remote_url=$(git -C "$checkout_root" config --get remote.origin.url 2>/dev/null) && [[ -n "$remote_url" ]]; then
    remote_base=$(basename -- "$remote_url")
    remote_base=${remote_base%.git}
    remote_base=$(sanitize_component "$remote_base")
    if [[ -n "$remote_base" ]]; then
      printf '%s\n' "$remote_base"
      return 0
    fi
  fi

  if common_dir=$(git -C "$checkout_root" rev-parse --git-common-dir 2>/dev/null) && [[ -n "$common_dir" ]]; then
    if [[ "$common_dir" != /* ]]; then
      common_dir=$(cd "$checkout_root/$common_dir" 2>/dev/null && pwd -P)
    fi

    common_parent=$(basename -- "$(dirname -- "$common_dir")")
    common_parent=$(sanitize_component "$common_parent")
    if [[ -n "$common_parent" && "$common_parent" != ".git" ]]; then
      printf '%s\n' "$common_parent"
      return 0
    fi
  fi

  printf '%s\n' "$(sanitize_component "$current_base")"
}
