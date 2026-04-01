#!/usr/bin/env zsh

_pi_resolve_bin() {
  local name="$1"
  shift

  if [[ "$name" == */* ]]; then
    [[ -x "$name" ]] && {
      print -r -- "$name"
      return 0
    }
  else
    local resolved=""
    rehash 2>/dev/null || true
    if resolved=$(whence -p "$name" 2>/dev/null) && [[ -n "$resolved" ]]; then
      print -r -- "$resolved"
      return 0
    fi
  fi

  local candidate
  for candidate in "$@"; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    print -r -- "$candidate"
    return 0
  done

  return 1
}

_pi_dotfiles_bin() {
  local bin_dir="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}"
  if [[ -d "$bin_dir" ]]; then
    print -r -- "$bin_dir"
    return 0
  fi

  bin_dir="$HOME/.config/dotfiles/bin"
  [[ -d "$bin_dir" ]] || return 1
  print -r -- "$bin_dir"
}

_pi_source_tmux_lib() {
  local dotfiles_bin lib_path
  dotfiles_bin=$(_pi_dotfiles_bin) || return 1
  lib_path="$dotfiles_bin/tmux-lib.sh"
  [[ -f "$lib_path" ]] || return 1

  # shellcheck source=bin/tmux-lib.sh
  source "$lib_path"
}

piw() {
  if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    cat <<'EOF'
Usage: piw [worktree-name] [pi args...]
       piw -- [pi args...]

Create a sibling git worktree, cd into it, and launch pi there.
If no worktree name is provided, piw auto-generates one.

Examples:
  piw fix-bug
  piw -- "Investigate the flaky test failure"
  piw review-123 --model sonnet
EOF
    return 0
  fi

  local worktree_name=""
  if [[ ${1:-} == "--" ]]; then
    shift
  elif [[ $# -gt 0 && ${1:-} != -* ]]; then
    worktree_name="$1"
    shift
  fi

  local dotfiles_bin root_helper checkout_root worktree_slug worktree_path pi_bin
  dotfiles_bin=$(_pi_dotfiles_bin) || {
    print -u2 'error: unable to locate DOTFILES_BIN for piw'
    return 1
  }
  root_helper="${TMUX_PROJECT_ROOT_BIN:-$dotfiles_bin/tmux-project-root}"
  [[ -x "$root_helper" ]] || root_helper="$HOME/.config/dotfiles/bin/tmux-project-root"
  [[ -x "$root_helper" ]] || {
    print -u2 'error: tmux-project-root helper not found'
    return 1
  }

  _pi_source_tmux_lib || {
    print -u2 'error: tmux worktree helpers not found'
    return 1
  }

  if [[ -n "$worktree_name" ]]; then
    worktree_slug="$worktree_name"
  else
    worktree_slug=$(default_worktree_slug pi)
  fi

  checkout_root=$($root_helper .) || return 1
  worktree_path=$(create_sibling_worktree "$checkout_root" "$worktree_slug") || return 1

  pi_bin=$(_pi_resolve_bin "${PI_REAL_BIN:-pi}" \
    "/etc/profiles/per-user/$USER/bin/pi" \
    "/run/current-system/sw/bin/pi" \
    "$HOME/.nix-profile/bin/pi" \
    "/opt/homebrew/bin/pi") || {
      print -u2 'error: pi binary not found'
      return 1
    }

  cd "$worktree_path" || return 1
  "$pi_bin" "$@"
}

pir() {
  if [[ $# -eq 0 ]]; then
    print -u2 'Usage: pir <pr-number> [pi args...]'
    return 1
  fi

  if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    cat <<'EOF'
Usage: pir <pr-number> [pi args...]

Show quick PR context with gh, check out the PR locally, and launch pi with a
review-oriented prompt.

Examples:
  pir 123
  pir 123 --model sonnet
EOF
    return 0
  fi

  local pr_number="$1"
  shift

  if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
    print -u2 'Usage: pir <pr-number> [pi args...]'
    return 1
  fi

  if (( $+functions[_agent_safe_cwd] )); then
    local safe_cwd
    safe_cwd=$(_agent_safe_cwd) || return 1
    cd "$safe_cwd" || return 1
  fi

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print -u2 'error: pir must be run inside a git repository'
    return 1
  fi

  local gh_bin pi_bin review_prompt
  gh_bin=$(_pi_resolve_bin "${GH_BIN:-gh}" \
    "/etc/profiles/per-user/$USER/bin/gh" \
    "/run/current-system/sw/bin/gh" \
    "$HOME/.nix-profile/bin/gh" \
    "/opt/homebrew/bin/gh") || {
      print -u2 'error: gh not found; pir requires GitHub CLI'
      return 1
    }

  "$gh_bin" pr view "$pr_number" --json number,title,baseRefName,headRefName,url,author \
    --jq '"reviewing PR #\(.number): \(.title)\nbase: \(.baseRefName) ← head: \(.headRefName)\nurl: \(.url)\nauthor: \(.author.login)"' \
    1>&2 || true

  if ! "$gh_bin" pr checkout "$pr_number"; then
    cat >&2 <<'EOF'
pir: gh pr checkout failed.
If your current checkout is dirty, either stash first or use `piw` to start from a fresh sibling worktree.
EOF
    return 1
  fi

  pi_bin=$(_pi_resolve_bin "${PI_REAL_BIN:-pi}" \
    "/etc/profiles/per-user/$USER/bin/pi" \
    "/run/current-system/sw/bin/pi" \
    "$HOME/.nix-profile/bin/pi" \
    "/opt/homebrew/bin/pi") || {
      print -u2 'error: pi binary not found'
      return 1
    }

  review_prompt="Review the checked-out GitHub PR #$pr_number. Start with a concise summary of the change, then inspect the diff carefully. Use /critique, /critique-review, or /diff-review when helpful."
  "$pi_bin" "$@" "$review_prompt"
}
