#!/usr/bin/env python3
"""Sweep unmanaged HA automations, scenes, and scripts after Nix deploy.

Connects to HA via WebSocket, compares running entities against the
Nix-declared set (passed as a JSON file argument), and removes orphans
from the entity registry.

The JSON file is generated at build time from the evaluated NixOS config.

Usage:
  python3 sweep-unmanaged.py /path/to/declared-entities.json [--dry-run]

Requires the same auth setup as apply-devices.py (agent-automation token).
"""

import asyncio
import base64
import hashlib
import hmac
import json
import sys
import time
from pathlib import Path

try:
    import websockets
except ImportError:
    print("ERROR: Need 'websockets' package", file=sys.stderr)
    sys.exit(1)

HA_URL = "ws://127.0.0.1:8123/api/websocket"
AUTH_PATH = "/var/lib/hass/.storage/auth"
TOKEN_CLIENT_NAME = "agent-automation"

DRY_RUN = "--dry-run" in sys.argv


def generate_token() -> str:
    """Generate a JWT from HA auth storage."""
    auth = json.loads(Path(AUTH_PATH).read_text())
    for t in auth["data"]["refresh_tokens"]:
        if t.get("client_name") == TOKEN_CLIENT_NAME:
            header = base64.urlsafe_b64encode(
                json.dumps({"alg": "HS256", "typ": "JWT"}).encode()
            ).rstrip(b"=")
            now = int(time.time())
            payload = base64.urlsafe_b64encode(
                json.dumps({"iss": t["id"], "iat": now, "exp": now + 3600}).encode()
            ).rstrip(b"=")
            sig_input = header + b"." + payload
            sig = base64.urlsafe_b64encode(
                hmac.new(t["jwt_key"].encode(), sig_input, hashlib.sha256).digest()
            ).rstrip(b"=")
            return (sig_input + b"." + sig).decode()
    raise RuntimeError(f"No refresh token with client_name={TOKEN_CLIENT_NAME!r}")


async def ws_call(ws, msg_id: int, payload: dict) -> dict:
    """Send a WS command and wait for its result."""
    payload["id"] = msg_id
    await ws.send(json.dumps(payload))
    while True:
        resp = json.loads(await ws.recv())
        if resp.get("id") == msg_id:
            return resp


async def sweep():
    # Parse args
    json_path = next((a for a in sys.argv[1:] if not a.startswith("-")), None)
    if not json_path:
        print("Usage: sweep-unmanaged.py <declared-entities.json> [--dry-run]", file=sys.stderr)
        sys.exit(1)

    declared = json.loads(Path(json_path).read_text())
    declared_automation_ids = set(declared.get("automation_ids", []))
    declared_scene_entity_ids = set(declared.get("scene_entity_ids", []))
    declared_script_entity_ids = set(declared.get("script_entity_ids", []))

    print(f"Declared: {len(declared_automation_ids)} automations, "
          f"{len(declared_scene_entity_ids)} scenes, "
          f"{len(declared_script_entity_ids)} scripts")

    token = generate_token()
    async with websockets.connect(HA_URL) as ws:
        # Auth
        auth_req = json.loads(await ws.recv())
        assert auth_req["type"] == "auth_required"
        await ws.send(json.dumps({"type": "auth", "access_token": token}))
        auth_resp = json.loads(await ws.recv())
        if auth_resp["type"] != "auth_ok":
            print(f"Auth failed: {auth_resp}", file=sys.stderr)
            sys.exit(1)

        msg_id = 1

        # Get all entity registry entries
        resp = await ws_call(ws, msg_id, {"type": "config/entity_registry/list"})
        msg_id += 1
        entities = resp["result"]

        removed = 0
        skipped = 0

        for ent in entities:
            eid = ent["entity_id"]
            domain = eid.split(".")[0]
            uid = ent.get("unique_id", "")
            platform = ent.get("platform", "")

            if domain == "automation":
                if uid in declared_automation_ids:
                    continue
                # Only touch YAML-sourced automations (platform = "automation")
                if platform not in ("automation",):
                    skipped += 1
                    continue

            elif domain == "scene":
                if eid in declared_scene_entity_ids:
                    continue
                # Only touch homeassistant-platform scenes (YAML-sourced)
                if platform not in ("homeassistant",):
                    skipped += 1
                    continue

            elif domain == "script":
                if eid in declared_script_entity_ids:
                    continue
                if platform not in ("script",):
                    skipped += 1
                    continue

            else:
                continue

            # This entity is unmanaged — remove it
            if DRY_RUN:
                print(f"  [dry-run] would remove: {eid} (uid={uid}, platform={platform})")
            else:
                print(f"  removing: {eid} (uid={uid})")
                resp = await ws_call(
                    ws, msg_id,
                    {"type": "config/entity_registry/remove", "entity_id": eid},
                )
                msg_id += 1
                if not resp.get("success"):
                    print(f"    WARN: failed: {resp.get('error', resp)}", file=sys.stderr)
            removed += 1

        # Also wipe UI YAML files to prevent UI-created entities from persisting
        if not DRY_RUN:
            from pathlib import Path as P
            config_dir = P("/var/lib/hass")
            for fname in ("automations.yaml", "scenes.yaml", "scripts.yaml"):
                fpath = config_dir / fname
                if fpath.exists():
                    content = fpath.read_text().strip()
                    if content and content != "[]" and content != "{}":
                        print(f"  wiping UI file: {fname}")
                        # automations/scenes are lists, scripts are dicts
                        empty = "{}" if fname == "scripts.yaml" else "[]"
                        fpath.write_text(empty + "\n")

        action = "would remove" if DRY_RUN else "removed"
        print(f"\nSweep done: {action} {removed}, skipped {skipped} (integration-owned)")


if __name__ == "__main__":
    asyncio.run(sweep())
