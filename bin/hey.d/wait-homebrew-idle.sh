#!/usr/bin/env bash
set -euo pipefail

deadline=$((SECONDS + ${HEY_HOMEBREW_WAIT_TIMEOUT:-600}))
warned=0

homebrew_pids() {
  ps ax -o pid= -o command= \
    | awk '($0 ~ /\/opt\/homebrew\/Library\/Homebrew\/[b]rew\.rb/) && (index($0, " bundle ") || index($0, " fetch ") || index($0, " install ") || index($0, " upgrade ")) {print $1}'
}

homebrew_processes() {
  ps ax -o pid= -o command= \
    | awk '($0 ~ /\/opt\/homebrew\/Library\/Homebrew\/[b]rew\.rb/) && (index($0, " bundle ") || index($0, " fetch ") || index($0, " install ") || index($0, " upgrade ")) {print "  " $0}'
}

while true; do
  pids=$(homebrew_pids)
  if [ -z "$pids" ]; then
    exit 0
  fi

  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: timed out waiting for existing Homebrew process(es) before rebuild:" >&2
    homebrew_processes >&2
    exit 1
  fi

  if [ "$warned" -eq 0 ]; then
    echo "hey re: waiting for existing Homebrew process(es) to finish before rebuild: $pids" >&2
    warned=1
  fi
  sleep 5
done
