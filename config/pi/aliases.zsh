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

_pi_shared_checkout_root() {
  local checkout_root="${1:-.}"
  local repo_root common_dir
  repo_root=$(git -C "$checkout_root" rev-parse --show-toplevel 2>/dev/null) || return 1
  common_dir=$(git -C "$checkout_root" rev-parse --git-common-dir 2>/dev/null) || return 1

  if [[ "$common_dir" != /* ]]; then
    common_dir=$(cd "$repo_root/$common_dir" 2>/dev/null && pwd -P) || return 1
  fi

  if [[ $(basename -- "$common_dir") == ".git" ]]; then
    dirname -- "$common_dir"
    return 0
  fi

  print -r -- "$repo_root"
}

_pi_create_repo_worktree() {
  local checkout_root="$1"
  local requested_name="$2"
  local repo_root slug repo_stem worktrees_dir worktree_path branch_name

  if ! git -C "$checkout_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print -u2 -- "error: not inside a git worktree: $checkout_root"
    return 1
  fi

  repo_root=$(_pi_shared_checkout_root "$checkout_root") || {
    print -u2 'error: unable to determine shared checkout root for piw'
    return 1
  }

  slug=$(sanitize_component "$requested_name")
  if [[ -z "$slug" ]]; then
    print -u2 'error: empty worktree name after sanitization'
    return 1
  fi

  repo_stem=$(resolve_repo_stem "$checkout_root")
  branch_name="${repo_stem}-${slug}"
  worktrees_dir="$repo_root/.pi/worktrees"
  worktree_path="$worktrees_dir/$slug"

  mkdir -p "$worktrees_dir" || return 1

  if [[ -e "$worktree_path" ]]; then
    print -u2 -- "error: worktree path already exists: $worktree_path"
    return 1
  fi

  if git -C "$checkout_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
    git -C "$checkout_root" worktree add --quiet "$worktree_path" "$branch_name"
  else
    git -C "$checkout_root" worktree add --quiet -b "$branch_name" "$worktree_path" HEAD
  fi

  print -r -- "$worktree_path"
}

piw() {
  if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    cat <<'EOF'
Usage: piw [worktree-name] [pi args...]
       piw -- [pi args...]

Create a git worktree under .pi/worktrees/, cd into it, and launch pi there.
If no worktree name is provided, piw auto-generates one.

Examples:
  piw fix-bug
  piw -- "Investigate the flaky test failure"
  piw review-123 --model sonnet
EOF
    return 0
  fi

  local worktree_name=""
  local checkout_root worktree_slug worktree_path pi_bin
  if [[ ${1:-} == "--" ]]; then
    shift
  elif [[ $# -gt 0 && ${1:-} != -* ]]; then
    worktree_name="$1"
    shift
  fi

  _pi_source_tmux_lib || {
    print -u2 'error: tmux worktree helpers not found'
    return 1
  }

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print -u2 'error: piw must be run inside a git repository'
    return 1
  fi

  if [[ -n "$worktree_name" ]]; then
    worktree_slug="$worktree_name"
  else
    worktree_slug=$(default_worktree_slug pi)
  fi

  checkout_root=$(git rev-parse --show-toplevel) || return 1
  worktree_path=$(_pi_create_repo_worktree "$checkout_root" "$worktree_slug") || return 1

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
  if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    cat <<'EOF'
Usage: pir [pr-number] [pi args...]

Without a PR number, review the current checkout against origin/main.
With a PR number, show quick PR context with gh, check out the PR locally, and
launch pi with a review-oriented prompt.

Examples:
  pir
  pir --model sonnet
  pir 123
  pir 123 --model sonnet
EOF
    return 0
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

  local pi_bin review_prompt pr_number gh_bin review_base
  pi_bin=$(_pi_resolve_bin "${PI_REAL_BIN:-pi}" \
    "/etc/profiles/per-user/$USER/bin/pi" \
    "/run/current-system/sw/bin/pi" \
    "$HOME/.nix-profile/bin/pi" \
    "/opt/homebrew/bin/pi") || {
      print -u2 'error: pi binary not found'
      return 1
    }

  if [[ $# -eq 0 || ${1:-} == -* ]]; then
    review_base="origin/main"
    if ! git rev-parse --verify "$review_base^{commit}" >/dev/null 2>&1; then
      print -u2 "error: $review_base not found; run 'git fetch origin main' first"
      return 1
    fi

    git diff --stat "$review_base...HEAD" 1>&2 || true
    review_prompt="Review the current checkout against $review_base. Start with a concise summary of the change relative to $review_base, then inspect the diff carefully. Use /critique, /critique-review, or /diff-review when helpful."
    "$pi_bin" "$@" "$review_prompt"
    return $?
  fi

  pr_number="$1"
  shift

  if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
    print -u2 'Usage: pir [pr-number] [pi args...]'
    return 1
  fi

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
If your current checkout is dirty, either stash first or use `piw` to start from a fresh .pi/worktrees checkout.
EOF
    return 1
  fi

  review_prompt="Review the checked-out GitHub PR #$pr_number. Start with a concise summary of the change, then inspect the diff carefully. Use /critique, /critique-review, or /diff-review when helpful."
  "$pi_bin" "$@" "$review_prompt"
}

# pi-overwatch shortcuts
alias ow='pi-overwatch'
alias owf='PI_OVERWATCH_REFRESH_MS=500 PI_OVERWATCH_STALE_MS=12000 pi-overwatch'
alias owm='PI_OVERWATCH_REFRESH_MS=1500 PI_OVERWATCH_STALE_MS=30000 pi-overwatch'
