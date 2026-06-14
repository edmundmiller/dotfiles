#!/usr/bin/env zsh

# Lazy-load bun completions on first use instead of sourcing them during startup.
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
if [[ -s "$BUN_INSTALL/_bun" ]]; then
  function bun {
    unfunction bun bunx
    source "$BUN_INSTALL/_bun"
    command bun "$@"
  }
  function bunx { bun; command bunx "$@"; }
fi
