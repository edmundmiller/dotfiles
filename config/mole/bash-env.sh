#!/usr/bin/env bash
# BASH_ENV runs before $0 and the script arguments are initialized. Hand off
# immediately before the first command, then leave unrelated scripts alone.
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  trap '
    trap - DEBUG
    case "$0" in
      /opt/homebrew/bin/mo|/opt/homebrew/bin/mole|/opt/homebrew/Cellar/mole/*|/opt/homebrew/opt/mole/*)
        exec "$MOLE_BASH_BIN" "$0" "$@"
        ;;
    esac
  ' DEBUG
fi
