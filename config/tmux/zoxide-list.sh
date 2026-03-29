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

processed=0
printed=0
seen_dirs=""
noise_re='^(/tmp|/private/|/nix/|/dev/|/sys/)|(\.Trash|\.sdkman/tmp|/T$|/var/folders)'

while IFS= read -r dir; do
  ((++processed))
  ((processed > 120)) && break

  [[ -z "$dir" || ! -d "$dir" ]] && continue

  resolved_dir="$dir"
  bare_hub=false
  if [[ -x "$resolver" && ! -e "$dir/.git" && -e "$dir/HEAD" ]]; then
    resolved_dir=$($resolver "$dir" 2>/dev/null || true)
    [[ -z "$resolved_dir" ]] && continue
    bare_hub=true
  fi

  if [[ "$bare_hub" != true ]] && [[ $resolved_dir =~ $noise_re ]]; then
    continue
  fi

  [[ "$resolved_dir" == */.git ]] && continue

  already_seen=false
  while IFS= read -r seen_dir; do
    [[ -n "$seen_dir" && "$seen_dir" == "$resolved_dir" ]] && {
      already_seen=true
      break
    }
  done <<< "$seen_dirs"

  [[ "$already_seen" == true ]] && continue
  seen_dirs+="$resolved_dir"$'\n'
  printf '%s\n' "${resolved_dir/#$HOME/~}"
  ((++printed))
  ((printed >= 30)) && break

done < <("$ZOXIDE_BIN" query --list 2>/dev/null)

exit 0
