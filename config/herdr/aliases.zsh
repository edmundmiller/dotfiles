#!/usr/bin/env zsh

# Native: open a remote shell, or attach an address already running on the NUC.
# Add the machine once with: hc machine add nuc
hnuc() {
  local backend="${HERDR_BACKEND:-native}"
  if [[ "$backend" == legacy ]]; then
    command herdr --remote nuc "$@"
  elif (( $# )); then
    local terminal="$1"
    shift
    command hc attach "nuc/$terminal" "$@"
  else
    command hc run --on nuc
  fi
}
