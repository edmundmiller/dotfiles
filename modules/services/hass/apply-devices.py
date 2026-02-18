#!/usr/bin/env python3
"""Apply declarative device→area assignments from devices.yaml via HA WebSocket API.

Reads the auth storage to generate a JWT, connects via WebSocket,
fetches the device registry, and updates area assignments to match
the desired state in devices.yaml.

Idempotent — only sends updates for devices whose area differs.
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
    # Fall back to aiohttp if available (HA's own env)
    websockets = None
    try:
        import aiohttp
    except ImportError:
        print("ERROR: Need either 'websockets' or 'aiohttp' package", file=sys.stderr)
        sys.exit(1)

HA_URL = "ws://127.0.0.1:8123/api/websocket"
AUTH_PATH = "/var/lib/hass/.storage/auth"
TOKEN_CLIENT_NAME = "agent-automation"


def load_devices_yaml(path: str) -> dict[str, list[str]]:
    """Parse devices.yaml without PyYAML (stdlib only)."""
    areas: dict[str, list[str]] = {}
    current_area = None
    with open(path) as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped == "areas:":
                continue
            # Area key: "  living_room:"
            if stripped.endswith(":") and not stripped.startswith("-"):
                current_area = stripped[:-1].strip()
                areas[current_area] = []
            # Device name: '    - "Living Room"'
            elif stripped.startswith("-") and current_area is not None:
                name = stripped.lstrip("- ").strip().strip('"').strip("'")
                areas[current_area].append(name)
    return areas


def generate_token() -> str:
    """Generate a JWT from the HA auth storage (no external deps)."""
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
    raise RuntimeError(f"No refresh token with client_name={TOKEN_CLIENT_NAME!r} found")


async def apply_with_websockets(token: str, desired: dict[str, list[str]]):
    """Apply device→area assignments using the 'websockets' library."""
    async with websockets.connect(HA_URL) as ws:
        # Auth
        msg = json.loads(await ws.recv())
        assert msg["type"] == "auth_required"
        await ws.send(json.dumps({"type": "auth", "access_token": token}))
        msg = json.loads(await ws.recv())
        if msg["type"] != "auth_ok":
            print(f"Auth failed: {msg}", file=sys.stderr)
            sys.exit(1)

        # Ensure areas exist
        await ws.send(json.dumps({"id": 1, "type": "config/area_registry/list"}))
        resp = json.loads(await ws.recv())
        existing_areas = {a["area_id"] for a in resp["result"]}
        msg_id = 2
        for area_id in desired:
            if area_id not in existing_areas:
                await ws.send(json.dumps({"id": msg_id, "type": "config/area_registry/create", "name": area_id}))
                resp = json.loads(await ws.recv())
                print(f"  CREATE area {area_id!r}: {'ok' if resp.get('success') else 'FAIL'}")
                msg_id += 1

        # Fetch device registry
        await ws.send(json.dumps({"id": msg_id, "type": "config/device_registry/list"}))
        resp = json.loads(await ws.recv())
        devices = resp["result"]

        await _apply(ws, devices, desired, id_start=msg_id + 1)


async def apply_with_aiohttp(token: str, desired: dict[str, list[str]]):
    """Apply device→area assignments using aiohttp."""
    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(HA_URL) as ws:
            msg = await ws.receive_json()
            assert msg["type"] == "auth_required"
            await ws.send_json({"type": "auth", "access_token": token})
            msg = await ws.receive_json()
            if msg["type"] != "auth_ok":
                print(f"Auth failed: {msg}", file=sys.stderr)
                sys.exit(1)

            # Ensure areas exist
            await ws.send_json({"id": 1, "type": "config/area_registry/list"})
            resp = await ws.receive_json()
            existing_areas = {a["area_id"] for a in resp["result"]}
            msg_id = 2
            for area_id in desired:
                if area_id not in existing_areas:
                    await ws.send_json({"id": msg_id, "type": "config/area_registry/create", "name": area_id})
                    resp = await ws.receive_json()
                    print(f"  CREATE area {area_id!r}: {'ok' if resp.get('success') else 'FAIL'}")
                    msg_id += 1

            await ws.send_json({"id": msg_id, "type": "config/device_registry/list"})
            resp = await ws.receive_json()
            devices = resp["result"]

            await _apply_aiohttp(ws, devices, desired, id_start=msg_id + 1)


async def _apply(ws, devices, desired, id_start):
    """Send updates via websockets library."""
    msg_id = id_start
    name_to_device = {d["name_by_user"] or d["name"]: d for d in devices}

    updates = 0
    for area_id, names in desired.items():
        for name in names:
            dev = name_to_device.get(name)
            if dev is None:
                print(f"  SKIP {name!r} — not found in device registry")
                continue
            if dev.get("area_id") == area_id:
                print(f"  OK   {name!r} already in {area_id}")
                continue
            await ws.send(
                json.dumps(
                    {
                        "id": msg_id,
                        "type": "config/device_registry/update",
                        "device_id": dev["id"],
                        "area_id": area_id,
                    }
                )
            )
            resp = json.loads(await ws.recv())
            ok = resp.get("success", False)
            print(f"  {'SET' if ok else 'FAIL'} {name!r} → {area_id}")
            updates += 1
            msg_id += 1

    print(f"Done: {updates} update(s)")


async def _apply_aiohttp(ws, devices, desired, id_start):
    """Send updates via aiohttp."""
    msg_id = id_start
    name_to_device = {d["name_by_user"] or d["name"]: d for d in devices}

    updates = 0
    for area_id, names in desired.items():
        for name in names:
            dev = name_to_device.get(name)
            if dev is None:
                print(f"  SKIP {name!r} — not found in device registry")
                continue
            if dev.get("area_id") == area_id:
                print(f"  OK   {name!r} already in {area_id}")
                continue
            await ws.send_json(
                {
                    "id": msg_id,
                    "type": "config/device_registry/update",
                    "device_id": dev["id"],
                    "area_id": area_id,
                }
            )
            resp = await ws.receive_json()
            ok = resp.get("success", False)
            print(f"  {'SET' if ok else 'FAIL'} {name!r} → {area_id}")
            updates += 1
            msg_id += 1

    print(f"Done: {updates} update(s)")


def main():
    devices_yaml = sys.argv[1] if len(sys.argv) > 1 else "/var/lib/hass/devices.yaml"
    desired = load_devices_yaml(devices_yaml)
    print(f"Loaded {sum(len(v) for v in desired.values())} device assignments from {devices_yaml}")

    token = generate_token()

    if websockets is not None:
        asyncio.run(apply_with_websockets(token, desired))
    else:
        asyncio.run(apply_with_aiohttp(token, desired))


if __name__ == "__main__":
    main()
