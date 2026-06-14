#!/usr/bin/env zsh

# Entire CLI shell completion (use _cache to avoid slow subshell on every start)
if (( $+commands[entire] )); then
  _cache entire completion zsh
fi

alias oz="oz-preview"
