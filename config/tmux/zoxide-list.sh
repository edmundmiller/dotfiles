#!/usr/bin/env bash
# Top zoxide dirs for sesh picker, skipping bare worktree hubs and other noise.

set -u

# _ZO_DATA_DIR must be set — Nix sets it to $XDG_CACHE_HOME, not default location
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"

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

ZOXIDE_BIN="${ZOXIDE_BIN:-$(resolve_bin zoxide "/opt/homebrew/bin/zoxide" "/run/current-system/sw/bin/zoxide" "$HOME/.nix-profile/bin/zoxide")}"
[[ -n "$ZOXIDE_BIN" ]] || exit 0

resolver="${DOTFILES_BIN:-$HOME/.config/dotfiles/bin}/git-worktree-cwd"
[[ -x "$resolver" ]] || resolver="$HOME/.config/dotfiles/bin/git-worktree-cwd"

"$ZOXIDE_BIN" query --list 2>/dev/null \
  | grep -vE '/\.git$' \
  | head -120 \
  | while IFS= read -r dir; do
      [[ -z "$dir" || ! -d "$dir" ]] && continue

      resolved_dir="$dir"
      bare_hub=false
      if [[ -x "$resolver" && ! -e "$dir/.git" && -e "$dir/HEAD" ]]; then
        resolved_dir=$($resolver "$dir" 2>/dev/null || true)
        [[ -z "$resolved_dir" ]] && continue
        bare_hub=true
      fi

      if [[ "$bare_hub" != true ]] && printf '%s\n' "$resolved_dir" | grep -Eq '^(/tmp|/private/|/nix/|/dev/|/sys/)|(\.Trash|\.sdkman/tmp|/T$|/var/folders)'; then
        continue
      fi

      printf '%s\n' "$resolved_dir"
    done \
  | awk '!seen[$0]++' \
  | head -30 \
  | sed "s|^$HOME|~|"
