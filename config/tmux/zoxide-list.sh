#!/usr/bin/env bash
# Top zoxide dirs for sesh picker, skipping bare worktree hubs and other noise.

set -u

# _ZO_DATA_DIR must be set — Nix sets it to $XDG_CACHE_HOME, not default location
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"

resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
[[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"

zoxide query --list 2>/dev/null \
  | grep -vE '/\.git$' \
  | grep -vE '^(/tmp|/private/|/nix/|/dev/|/sys/)' \
  | grep -vE '(\.Trash|\.sdkman/tmp|/T$|/var/folders)' \
  | head -120 \
  | while IFS= read -r dir; do
      [[ -z "$dir" || ! -d "$dir" ]] && continue

      resolved_dir="$dir"
      if [[ -x "$resolver" && ! -e "$dir/.git" && -e "$dir/HEAD" ]]; then
        resolved_dir=$($resolver "$dir" 2>/dev/null || true)
        [[ -z "$resolved_dir" ]] && continue
      fi

      printf '%s\n' "$resolved_dir"
    done \
  | awk '!seen[$0]++' \
  | head -30 \
  | sed "s|^$HOME|~|"
