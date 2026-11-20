#!/usr/bin/env bash
# List HA entities, optionally filtered by domain.
# Requires TOKEN env var.
# Usage:
#   ha-entities.sh                    # all entities
#   ha-entities.sh media_player       # just media players
#   ha-entities.sh input_boolean      # just input booleans
set -euo pipefail

DOMAIN="${1:-}"
HA="${HA_URL:-http://127.0.0.1:8123}"
[[ -n "${TOKEN:-}" ]] || { echo "ERROR: TOKEN env var required" >&2; exit 1; }

curl -s -H "Authorization: Bearer $TOKEN" "$HA/api/states" \
  | python3 -c "
import json, sys
domain_filter = '$DOMAIN'
states = json.load(sys.stdin)
for s in sorted(states, key=lambda x: x['entity_id']):
    eid = s['entity_id']
    if domain_filter and not eid.startswith(domain_filter + '.'):
        continue
    state = s['state']
    name = s['attributes'].get('friendly_name', '')
    print(f'{eid:45} {state:15} {name}')
"
