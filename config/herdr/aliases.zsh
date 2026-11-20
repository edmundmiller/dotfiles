#!/usr/bin/env zsh

# Native: open a remote shell, or attach an address already running on the NUC.
# Mac activation registers the NUC through native.machines.
hnuc() {
  if (( $# )); then
    local terminal="$1"
    shift
    command hc attach "nuc/$terminal" "$@"
  else
    command hc run --on nuc
  fi
}
