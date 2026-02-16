#!/usr/bin/env bash
# Add a Home Assistant integration via config flow API.
# Requires TOKEN env var (from create-ha-token.sh).
# Usage: TOKEN=eyJ... bash ha-add-integration.sh <domain> [arg]
set -euo pipefail

DOMAIN="${1:?Usage: ha-add-integration.sh <domain> [arg]}"
ARG="${2:-}"
HA="http://127.0.0.1:8123"

if [[ -z "${TOKEN:-}" ]]; then
  echo "ERROR: TOKEN env var required" >&2
  exit 1
fi

api() {
  curl -sf -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$@"
}

start_flow() {
  api -X POST -d "{\"handler\": \"$DOMAIN\", \"show_advanced_options\": false}" \
    "$HA/api/config/config_entries/flow"
}

submit_step() {
  local flow_id="$1" data="$2"
  api -X POST -d "$data" "$HA/api/config/config_entries/flow/$flow_id"
}

abort_flow() {
  api -X DELETE "$HA/api/config/config_entries/flow/$1" || true
}

echo "Starting config flow for: $DOMAIN"
RESP=$(start_flow)
TYPE=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['type'])")
FLOW_ID=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['flow_id'])")

if [[ "$TYPE" == "abort" ]]; then
  REASON=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('reason','unknown'))")
  echo "Flow aborted: $REASON"
  exit 1
fi

case "$DOMAIN" in
  matter)
    URL="${ARG:-ws://localhost:5580/ws}"
    echo "Connecting to matter-server at $URL"
    RESP=$(submit_step "$FLOW_ID" "{\"url\": \"$URL\"}")
    ;;

  homekit_controller)
    # Step 1: select device
    DEVICES=$(echo "$RESP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for field in data.get('data_schema', []):
    if field['name'] == 'device':
        for opt in field['options']:
            print(opt[0])
")
    if [[ -z "$DEVICES" ]]; then
      echo "No HomeKit devices found"
      abort_flow "$FLOW_ID"
      exit 1
    fi

    DEVICE=$(echo "$DEVICES" | head -1)
    echo "Selecting device: $DEVICE"
    RESP=$(submit_step "$FLOW_ID" "{\"device\": \"$DEVICE\"}")
    TYPE=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['type'])")

    if [[ "$TYPE" == "form" ]]; then
      # Step 2: pairing code
      if [[ -n "$ARG" ]]; then
        PIN="$ARG"
      elif [[ -f /var/lib/homebridge/config.json ]]; then
        PIN=$(python3 -c "import json; print(json.load(open('/var/lib/homebridge/config.json'))['bridge']['pin'])")
        echo "Auto-detected Homebridge pin: $PIN"
      else
        echo "ERROR: Pairing code required. Pass as second argument." >&2
        abort_flow "$FLOW_ID"
        exit 1
      fi
      RESP=$(submit_step "$FLOW_ID" "{\"pairing_code\": \"$PIN\"}")
    fi
    ;;

  cast)
    HOSTS="${ARG:-}"
    if [[ -n "$HOSTS" ]]; then
      RESP=$(submit_step "$FLOW_ID" "{\"known_hosts\": [\"$HOSTS\"]}")
    else
      RESP=$(submit_step "$FLOW_ID" "{\"known_hosts\": []}")
    fi
    ;;

  apple_tv)
    INPUT="${ARG:?Apple TV requires device name or IP as second argument}"
    echo "Searching for: $INPUT"
    RESP=$(submit_step "$FLOW_ID" "{\"device_input\": \"$INPUT\"}")
    ;;

  samsungtv)
    HOST="${ARG:?Samsung TV requires host IP as second argument}"
    echo "Connecting to: $HOST"
    RESP=$(submit_step "$FLOW_ID" "{\"host\": \"$HOST\"}")
    ;;

  *)
    echo "Unknown domain: $DOMAIN. Dumping flow response:"
    echo "$RESP" | python3 -m json.tool
    exit 1
    ;;
esac

# Check result
TYPE=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['type'])")
if [[ "$TYPE" == "create_entry" ]]; then
  TITLE=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
  echo "✅ Integration added: $TITLE"
elif [[ "$TYPE" == "form" ]]; then
  echo "⚠️  Flow needs more input:"
  echo "$RESP" | python3 -m json.tool
elif [[ "$TYPE" == "abort" ]]; then
  REASON=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('reason','unknown'))")
  echo "❌ Flow aborted: $REASON"
  exit 1
else
  echo "Response:"
  echo "$RESP" | python3 -m json.tool
fi
