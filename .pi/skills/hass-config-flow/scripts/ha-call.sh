#!/usr/bin/env bash
# Call an HA service.
# Requires TOKEN env var.
# Usage:
#   ha-call.sh media_player.turn_off media_player.tv
#   ha-call.sh input_select.select_option input_select.house_mode '{"option":"Movie"}'
#   ha-call.sh script.turn_on script.everything_off
set -euo pipefail

SERVICE="${1:?Usage: ha-call.sh domain.service entity_id [extra_json]}"
ENTITY="${2:?Usage: ha-call.sh domain.service entity_id [extra_json]}"
EXTRA="${3:-}"
HA="${HA_URL:-http://127.0.0.1:8123}"

[[ -n "${TOKEN:-}" ]] || { echo "ERROR: TOKEN env var required" >&2; exit 1; }

DOMAIN="${SERVICE%%.*}"
ACTION="${SERVICE#*.}"

# Merge entity_id with any extra data
if [[ -n "$EXTRA" ]]; then
  BODY=$(python3 -c "
import json
base = {'entity_id': '$ENTITY'}
base.update(json.loads('$EXTRA'))
print(json.dumps(base))
")
else
  BODY="{\"entity_id\":\"$ENTITY\"}"
fi

RESP=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "$HA/api/services/$DOMAIN/$ACTION")

if [[ -n "$RESP" ]]; then
  echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
else
  echo "✅ $SERVICE called on $ENTITY"
fi
