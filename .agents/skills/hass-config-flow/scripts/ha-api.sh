#!/usr/bin/env bash
# General-purpose HA REST API wrapper.
# Run on NUC or locally via SSH.
# Requires TOKEN env var.
#
# Usage:
#   ha-api.sh GET  /api/states/input_select.house_mode
#   ha-api.sh POST /api/services/media_player/turn_off '{"entity_id":"media_player.tv"}'
#   ha-api.sh POST /api/config/config_entries/flow '{"handler":"spotify"}'
set -euo pipefail

METHOD="${1:?Usage: ha-api.sh METHOD /path [json_body]}"
PATH_="${2:?Usage: ha-api.sh METHOD /path [json_body]}"
BODY="${3:-}"
HA="${HA_URL:-http://127.0.0.1:8123}"

[[ -n "${TOKEN:-}" ]] || { echo "ERROR: TOKEN env var required" >&2; exit 1; }

ARGS=(
  -s
  -H "Authorization: Bearer $TOKEN"
  -H "Content-Type: application/json"
  -X "$METHOD"
)

[[ -n "$BODY" ]] && ARGS+=(-d "$BODY")

curl "${ARGS[@]}" "${HA}${PATH_}" | python3 -m json.tool 2>/dev/null || cat
