#!/usr/bin/env bash
# Generate a JWT for an existing HA long-lived access token.
# Run on NUC: sudo bash ha-token.sh [token_name]
# Does NOT restart HA — only reads auth storage.
set -euo pipefail

NAME="${1:-agent-automation}"
AUTH="/var/lib/hass/.storage/auth"

[[ -f "$AUTH" ]] || { echo "ERROR: $AUTH not found" >&2; exit 1; }

python3 << PYEOF
import hashlib, hmac, base64, time, json

auth = json.load(open("$AUTH"))
for t in auth["data"]["refresh_tokens"]:
    if t.get("client_name") == "$NAME":
        header = base64.urlsafe_b64encode(json.dumps({"alg":"HS256","typ":"JWT"}).encode()).rstrip(b"=")
        now = int(time.time())
        payload = base64.urlsafe_b64encode(json.dumps({"iss":t["id"],"iat":now,"exp":now+86400*365}).encode()).rstrip(b"=")
        sig_input = header + b"." + payload
        sig = base64.urlsafe_b64encode(hmac.new(t["jwt_key"].encode(), sig_input, hashlib.sha256).digest()).rstrip(b"=")
        print((sig_input + b"." + sig).decode())
        break
else:
    import sys
    print(f"ERROR: no token named '$NAME' found", file=sys.stderr)
    names = [t.get("client_name","?") for t in auth["data"]["refresh_tokens"] if t.get("token_type") == "long_lived_access_token"]
    print(f"Available: {', '.join(names)}", file=sys.stderr)
    sys.exit(1)
PYEOF
