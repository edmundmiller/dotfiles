#!/usr/bin/env bash
# Shared tmux/worktree shell helpers.

sanitize_component() {
  local value="$1"
  value=$(printf '%s' "$value" | sed -E 's/[^[:alnum:]_-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  printf '%s\n' "$value"
}

default_worktree_slug() {
  local prefix="${1:-wt}"
  local stamp
  stamp=$(date +%Y%m%d-%H%M%S)
  printf '%s\n' "$(sanitize_component "${prefix}-${stamp}")"
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

create_sibling_worktree() {
  local checkout_root="$1"
  local requested_name="$2"
  local repo_stem slug worktree_name worktree_path branch_name

  if ! git -C "$checkout_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: not inside a git worktree: $checkout_root" >&2
    return 1
  fi

  slug=$(sanitize_component "$requested_name")
  if [[ -z "$slug" ]]; then
    echo "error: empty worktree name after sanitization" >&2
    return 1
  fi

  repo_stem=$(resolve_repo_stem "$checkout_root")
  worktree_name="${repo_stem}-${slug}"
  worktree_path="$(dirname -- "$checkout_root")/${worktree_name}"
  branch_name="$worktree_name"

  if [[ -e "$worktree_path" ]]; then
    echo "error: worktree path already exists: $worktree_path" >&2
    return 1
  fi

  if git -C "$checkout_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
    git -C "$checkout_root" worktree add --quiet "$worktree_path" "$branch_name"
  else
    git -C "$checkout_root" worktree add --quiet -b "$branch_name" "$worktree_path" HEAD
  fi

  printf '%s\n' "$worktree_path"
}
