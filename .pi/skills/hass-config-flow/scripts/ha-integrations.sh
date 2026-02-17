#!/usr/bin/env bash
# List all configured HA integrations.
# Requires TOKEN env var.
# Usage: TOKEN=eyJ... bash ha-integrations.sh
set -euo pipefail

HA="${HA_URL:-http://127.0.0.1:8123}"
[[ -n "${TOKEN:-}" ]] || { echo "ERROR: TOKEN env var required" >&2; exit 1; }

curl -s -H "Authorization: Bearer $TOKEN" "$HA/api/config/config_entries/entry" \
  | python3 -c "
import json, sys
entries = json.load(sys.stdin)
for e in sorted(entries, key=lambda x: x['domain']):
    state = e['state']
    icon = '✅' if state == 'loaded' else '❌' if state == 'setup_error' else '⏳'
    print(f'{icon} {e[\"domain\"]:30} {e[\"title\"]:30} ({state})')
print(f'\n{len(entries)} integrations total')
"
