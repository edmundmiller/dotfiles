#!/usr/bin/env bash
set -euo pipefail

processes=$(ps ax -o pid= -o command= \
  | awk '($0 ~ /\/opt\/homebrew\/Library\/Homebrew\/[b]rew\.rb/) && (index($0, " bundle ") || index($0, " fetch ") || index($0, " install ") || index($0, " upgrade ")) {print "  " $0}')

if [ -n "$processes" ]; then
  echo "hey re: Homebrew operation(s) may be active; continuing without waiting:" >&2
  printf '%s\n' "$processes" >&2
  echo "hey re: if Homebrew activation fails, let the other operation finish and rerun hey re." >&2
fi

exit 0
