function tower-auth {
  [[ -n "${TOWER_ACCESS_TOKEN:-}" ]] && return 0

  local token
  token="$(op read 'op://Employee/5m7bgfkukzaekmzo5ew2nwmeuq/credential')" || return
  [[ -n "$token" ]] || return 1
  export TOWER_ACCESS_TOKEN="$token"
}
