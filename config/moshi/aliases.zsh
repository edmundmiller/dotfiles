# Moshi host helpers.
#
# `moshi [dir] [session]` mirrors Moshi's recommended tmux attach pattern:
# resolve a project directory, derive a short session name, and replace this
# shell with `tmux new-session -A` so no wrapper process remains.
moshi() {
  emulate -L zsh
  setopt local_options no_unset

  if whence -p moshi >/dev/null 2>&1; then
    command moshi "$@"
    return $?
  fi

  local dir="${1:-.}"
  local session="${2:-}"

  if ! command -v tmux >/dev/null 2>&1; then
    print -u2 "moshi: tmux is not available"
    return 127
  fi

  dir="${dir/#\~/$HOME}"
  if [[ ! -d "$dir" ]]; then
    print -u2 "moshi: directory not found: $dir"
    return 1
  fi

  dir="$(cd "$dir" && pwd -P)" || return

  if [[ -z "$session" ]]; then
    session="${dir:t}"
    session="${session//[^A-Za-z0-9_.-]/-}"
  fi

  exec tmux new-session -A -s "$session" -c "$dir"
}

moshi-status() {
  if command -v moshi-hook >/dev/null 2>&1; then
    moshi-hook status "$@"
  else
    print -u2 "moshi-status: moshi-hook is not available"
    return 127
  fi
}

moshi-logs() {
  if command -v moshi-hook >/dev/null 2>&1; then
    moshi-hook logs -f "$@"
  else
    print -u2 "moshi-logs: moshi-hook is not available"
    return 127
  fi
}
