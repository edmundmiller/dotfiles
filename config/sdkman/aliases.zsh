#!/usr/bin/env zsh

# SDKMAN - lazy load (~100ms savings)
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  function sdk {
    unfunction sdk java gradle kotlin groovy maven
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdk "$@"
  }
  for cmd in java gradle kotlin groovy maven; do
    eval "function $cmd { sdk; command $cmd \"\$@\"; }"
  done
fi
