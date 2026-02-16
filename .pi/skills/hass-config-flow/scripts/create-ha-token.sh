#!/usr/bin/env bash
# Create a long-lived access token for Home Assistant API access.
# Run as root on the NixOS host: sudo bash create-ha-token.sh
# Outputs the token to stdout.
set -euo pipefail

AUTH_PATH="/var/lib/hass/.storage/auth"

if [[ ! -f "$AUTH_PATH" ]]; then
  echo "ERROR: $AUTH_PATH not found. Is Home Assistant installed?" >&2
  exit 1
fi

echo "Stopping home-assistant..." >&2
systemctl stop home-assistant
sleep 3

# Inject token and generate JWT
TOKEN=$(python3 << 'PYEOF'
import json, secrets, time, base64, hmac, hashlib
from datetime import datetime, timezone

auth_path = "/var/lib/hass/.storage/auth"
with open(auth_path) as f:
    auth = json.load(f)

# Find owner user
user_id = None
for u in auth["data"]["users"]:
    if u.get("is_owner"):
        user_id = u["id"]
        break

if not user_id:
    # Fall back to first non-system user
    for u in auth["data"]["users"]:
        if not u.get("system_generated"):
            user_id = u["id"]
            break

if not user_id:
    raise RuntimeError("No suitable user found in auth storage")

# Check if we already have an agent token
for t in auth["data"]["refresh_tokens"]:
    if t.get("client_name") == "agent-automation":
        # Reuse existing token's jwt_key to generate new JWT
        jwt_key = t["jwt_key"]
        token_id = t["id"]
        break
else:
    # Create new refresh token
    token_id = secrets.token_hex(16)
    jwt_key = secrets.token_hex(32)
    now = datetime.now(timezone.utc).isoformat()

    new_token = {
        "id": token_id,
        "user_id": user_id,
        "client_id": None,
        "client_name": "agent-automation",
        "client_icon": None,
        "token_type": "long_lived_access_token",
        "created_at": now,
        "access_token_expiration": 315360000.0,
        "token": secrets.token_hex(32),
        "jwt_key": jwt_key,
        "last_used_at": None,
        "last_used_ip": None,
        "credential_id": None,
        "version": "0.2",
    }
    auth["data"]["refresh_tokens"].append(new_token)

    with open(auth_path, "w") as f:
        json.dump(auth, f, indent=2)

# Build JWT (HS256)
header = base64.urlsafe_b64encode(
    json.dumps({"alg": "HS256", "typ": "JWT"}).encode()
).rstrip(b"=").decode()

now = int(time.time())
payload = base64.urlsafe_b64encode(
    json.dumps({"iss": token_id, "iat": now, "exp": now + 315360000}).encode()
).rstrip(b"=").decode()

signing_input = f"{header}.{payload}"
sig = hmac.new(jwt_key.encode(), signing_input.encode(), hashlib.sha256).digest()
signature = base64.urlsafe_b64encode(sig).rstrip(b"=").decode()

print(f"{signing_input}.{signature}")
PYEOF
)

echo "Starting home-assistant..." >&2
systemctl start home-assistant

# Wait for HA to be ready
echo "Waiting for HA to start..." >&2
for i in $(seq 1 30); do
  if curl -sf -o /dev/null "http://127.0.0.1:8123/api/" -H "Authorization: Bearer $TOKEN" 2>/dev/null; then
    echo "TOKEN=$TOKEN"
    exit 0
  fi
  sleep 2
done

echo "WARNING: HA may still be starting. Token generated but not verified." >&2
echo "TOKEN=$TOKEN"
