#!/usr/bin/env bash
# Top 30 zoxide dirs by frecency for sesh picker, excluding system/noise paths
/opt/homebrew/bin/zoxide query --list 2>/dev/null \
  | grep -vE '^(/tmp|/private/|/nix/|/dev/|/sys/)' \
  | grep -vE '(\.Trash|\.sdkman/tmp|/T$|/var/folders)' \
  | head -30
