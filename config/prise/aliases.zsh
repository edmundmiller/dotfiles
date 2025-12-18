#!/usr/bin/env zsh

# Prise - Terminal Multiplexer Aliases
# https://github.com/rockorager/prise

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
