#!/usr/bin/env bash
# Start or continue a config flow for an integration.
# Requires TOKEN env var.
# Usage:
#   ha-flow.sh start spotify                    # start new flow
#   ha-flow.sh submit <flow_id> '{"key":"val"}' # submit step data
#   ha-flow.sh abort <flow_id>                  # abort a flow
set -euo pipefail

CMD="${1:?Usage: ha-flow.sh start|submit|abort <args>}"
HA="${HA_URL:-http://127.0.0.1:8123}"
[[ -n "${TOKEN:-}" ]] || { echo "ERROR: TOKEN env var required" >&2; exit 1; }

api() {
  curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$@"
}

case "$CMD" in
  start)
    DOMAIN="${2:?Usage: ha-flow.sh start <domain>}"
    RESP=$(api -X POST -d "{\"handler\":\"$DOMAIN\"}" "$HA/api/config/config_entries/flow")
    TYPE=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['type'])")
    FLOW_ID=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['flow_id'])")

    case "$TYPE" in
      form)
        echo "📝 Flow $FLOW_ID needs input:"
        echo "$RESP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'  Step: {data.get(\"step_id\", \"?\")}')
print(f'  Description: {data.get(\"description_placeholders\", {})}')
for field in data.get('data_schema', []):
    req = '(required)' if field.get('required', True) else '(optional)'
    print(f'  - {field[\"name\"]:20} {field.get(\"type\",\"?\")} {req}')
"
        ;;
      create_entry)
        TITLE=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
        echo "✅ Integration created: $TITLE"
        ;;
      abort)
        REASON=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('reason','unknown'))")
        echo "❌ Aborted: $REASON"
        ;;
    esac
    echo "$RESP" | python3 -m json.tool
    ;;

  submit)
    FLOW_ID="${2:?Usage: ha-flow.sh submit <flow_id> <json_data>}"
    DATA="${3:?Usage: ha-flow.sh submit <flow_id> <json_data>}"
    RESP=$(api -X POST -d "$DATA" "$HA/api/config/config_entries/flow/$FLOW_ID")
    echo "$RESP" | python3 -m json.tool
    ;;

  abort)
    FLOW_ID="${2:?Usage: ha-flow.sh abort <flow_id>}"
    api -X DELETE "$HA/api/config/config_entries/flow/$FLOW_ID"
    echo "Flow $FLOW_ID aborted"
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    echo "Usage: ha-flow.sh start|submit|abort <args>" >&2
    exit 1
    ;;
esac
