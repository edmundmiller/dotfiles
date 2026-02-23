#!/usr/bin/env bash
# Top 30 zoxide dirs by frecency for sesh picker, excluding system/noise paths
# _ZO_DATA_DIR must be set — Nix sets it to $XDG_CACHE_HOME, not the default location
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"
zoxide query --list 2>/dev/null \
  | grep -vE '^(/tmp|/private/|/nix/|/dev/|/sys/)' \
  | grep -vE '(\.Trash|\.sdkman/tmp|/T$|/var/folders)' \
  | head -30 \
  | sed "s|^$HOME|~|"
