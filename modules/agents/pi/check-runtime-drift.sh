#!/usr/bin/env bash
# Warning-only Pi runtime drift check for prek/pre-push.
set -euo pipefail

warned=0
warn() {
  warned=1
  printf 'WARN: %s\n' "$*" >&2
}

pi_home="${PI_HOME:-$HOME/.pi/agent}"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if [ ! -d "$pi_home" ]; then
  warn "Pi home not found at $pi_home; run hey re before using pi."
else
  if [ -L "$pi_home/settings.json" ]; then
    target="$(readlink "$pi_home/settings.json")"
    case "$target" in
      /nix/store/*) ;;
      *) warn "Pi settings.json is not a Nix store symlink: $target" ;;
    esac
  else
    warn "Pi settings.json is not a symlink; repo-managed settings may not be applied."
  fi

  if [ -d "$pi_home/git" ]; then
    while IFS= read -r -d '' git_dir; do
      worktree="${git_dir%/.git}"
      status="$(git -C "$worktree" status --porcelain 2>/dev/null || true)"
      if [ -n "$status" ]; then
        warn "Dirty Pi git extension cache: $worktree"
      fi
    done < <(find "$pi_home/git" -type d -name .git -print0 2>/dev/null)
  fi
fi

if command -v pi >/dev/null 2>&1; then
  current_version="$(pi --version 2>/dev/null || true)"
  pinned_version="$(nix eval --raw "$repo_root#nixosConfigurations.$(hostname).pkgs.llm-agents.pi.version" 2>/dev/null || true)"
  if [ -n "$current_version" ] && [ -n "$pinned_version" ] && [ "$current_version" != "$pinned_version" ]; then
    warn "Pi binary version $current_version differs from repo-pinned $pinned_version; run hey re."
  fi
else
  warn "pi not found on PATH."
fi

if [ "$warned" -ne 0 ]; then
  cat >&2 <<'EOF'
Pi runtime drift detected. Suggested fixes:
  hey re
  pi update --extensions
EOF
fi

exit 0
