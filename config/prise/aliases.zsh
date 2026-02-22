#!/usr/bin/env zsh

# Prise - Terminal Multiplexer Aliases
# https://github.com/rockorager/prise

# Fix prise session files that contain URL-formatted cwd paths
# This is a workaround for a prise bug where OSC 7 URLs are stored
# in session files and cause ChdirFailed errors on restore
_prise_fix_session_cwds() {
  local sessions_dir="${HOME}/.local/state/prise/sessions"
  [[ -d "$sessions_dir" ]] || return 0
  
  for f in "$sessions_dir"/*.json(N); do
    # Check if file contains URL-formatted cwd
    if grep -q '"cwd": *"[a-z-]*://' "$f" 2>/dev/null; then
      # Strip URL protocol and hostname, keep just the path
      # kitty-shell-cwd://hostname/path -> /path
      # file://hostname/path -> /path
      sed -i.bak -E 's#"cwd": *"[a-z-]+://[^/]*(/.*)?"#"cwd": "\1"#g' "$f"
      rm -f "${f}.bak"
    fi
  done
}

# Run fix manually if needed: _prise_fix_session_cwds
# Removed from shell startup — scanning 80+ files per shell is too slow (~340ms)

# Basic prise commands
alias pa='prise'
alias pal='prise session list'
alias paa='prise session attach'
alias pad='prise session delete'

# Check if we're inside a prise session
if [[ -n $PRISE_SESSION ]]; then
  # Inside prise - add session-specific aliases

  # Create new session (from inside one)
  function pn {
    local name="${1:-${PWD:t}}"
    prise session create "$name"
  }

  # Rename current session
  function prename {
    local name="${1}"
    if [[ -z "$name" ]]; then
      echo "Usage: prename <new-name>"
      return 1
    fi
    prise session rename "$PRISE_SESSION" "$name"
  }
else
  # Outside prise

  # Attach to session or create new one
  function pat {
    local name="${1:-main}"
    prise session attach "$name" 2>/dev/null || prise -s "$name"
  }
fi
