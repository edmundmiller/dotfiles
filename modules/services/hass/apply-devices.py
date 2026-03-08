#!/usr/bin/env python3
"""Apply declarative device→area assignments + area icons from devices.yaml.

Reads auth storage to generate a JWT, connects via WebSocket,
fetches area/device registries, and updates assignments/icons to match
devices.yaml.

Idempotent — only sends updates for values that differ.
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
    # Fall back to aiohttp if available (HA env)
    websockets = None
    try:
        import aiohttp
    except ImportError:
        print("ERROR: Need either 'websockets' or 'aiohttp' package", file=sys.stderr)
        sys.exit(1)

HA_URL = "ws://127.0.0.1:8123/api/websocket"
AUTH_PATH = "/var/lib/hass/.storage/auth"
TOKEN_CLIENT_NAME = "agent-automation"


def load_devices_yaml(path: str) -> tuple[dict[str, list[str]], dict[str, str]]:
    """Parse devices.yaml without PyYAML (stdlib only).

    Expected shape:
      areas:
        room_id:
          - "Device Name"
      icons:
        room_id: mdi:icon-name
    """
    areas: dict[str, list[str]] = {}
    icons: dict[str, str] = {}

    section = None
    current_area = None

    with open(path) as f:
        for raw in f:
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue

            if stripped == "areas:":
                section = "areas"
                current_area = None
                continue
            if stripped == "icons:":
                section = "icons"
                current_area = None
                continue

            if section == "areas":
                # Area key: "  living_room:"
                if stripped.endswith(":") and not stripped.startswith("-"):
                    current_area = stripped[:-1].strip()
                    areas[current_area] = []
                    continue

                # Device name: '    - "Living Room"'
                if stripped.startswith("-") and current_area is not None:
                    name = stripped.lstrip("- ").strip().strip('"').strip("'")
                    areas[current_area].append(name)
                    continue

            if section == "icons" and not stripped.startswith("-") and ":" in stripped:
                area_id, icon = stripped.split(":", 1)
                area_id = area_id.strip()
                icon = icon.strip().strip('"').strip("'")
                if area_id and icon:
                    icons[area_id] = icon

    return areas, icons


def generate_token() -> str:
    """Generate a JWT from HA auth storage (no external deps)."""
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


async def apply_with_websockets(
    token: str, desired_areas: dict[str, list[str]], desired_icons: dict[str, str]
):
    """Apply area/device config using websockets library."""
    async with websockets.connect(HA_URL) as ws:
        # Auth
        msg = json.loads(await ws.recv())
        assert msg["type"] == "auth_required"
        await ws.send(json.dumps({"type": "auth", "access_token": token}))
        msg = json.loads(await ws.recv())
        if msg["type"] != "auth_ok":
            print(f"Auth failed: {msg}", file=sys.stderr)
            sys.exit(1)

        msg_id = 1
        msg_id = await _sync_areas_websockets(ws, desired_areas, desired_icons, msg_id)

        # Fetch device registry
        await ws.send(json.dumps({"id": msg_id, "type": "config/device_registry/list"}))
        resp = json.loads(await ws.recv())
        devices = resp["result"]

        await _apply_devices_websockets(ws, devices, desired_areas, msg_id + 1)


async def apply_with_aiohttp(
    token: str, desired_areas: dict[str, list[str]], desired_icons: dict[str, str]
):
    """Apply area/device config using aiohttp."""
    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(HA_URL) as ws:
            msg = await ws.receive_json()
            assert msg["type"] == "auth_required"
            await ws.send_json({"type": "auth", "access_token": token})
            msg = await ws.receive_json()
            if msg["type"] != "auth_ok":
                print(f"Auth failed: {msg}", file=sys.stderr)
                sys.exit(1)

            msg_id = 1
            msg_id = await _sync_areas_aiohttp(ws, desired_areas, desired_icons, msg_id)

            # Fetch device registry
            await ws.send_json({"id": msg_id, "type": "config/device_registry/list"})
            resp = await ws.receive_json()
            devices = resp["result"]

            await _apply_devices_aiohttp(ws, devices, desired_areas, msg_id + 1)


async def _sync_areas_websockets(ws, desired_areas, desired_icons, id_start):
    """Create missing areas and apply area icons via websockets."""
    await ws.send(json.dumps({"id": id_start, "type": "config/area_registry/list"}))
    resp = json.loads(await ws.recv())
    existing_areas = {a["area_id"]: a for a in resp["result"]}

    msg_id = id_start + 1
    all_area_ids = sorted(set(desired_areas) | set(desired_icons))

    for area_id in all_area_ids:
        if area_id in existing_areas:
            continue

        payload = {
            "id": msg_id,
            "type": "config/area_registry/create",
            "name": area_id,
        }
        if area_id in desired_icons:
            payload["icon"] = desired_icons[area_id]

        await ws.send(json.dumps(payload))
        create_resp = json.loads(await ws.recv())
        ok = create_resp.get("success", False)
        print(f"  {'CREATE' if ok else 'FAIL'} area {area_id!r}")
        if ok:
            existing_areas[area_id] = create_resp.get("result", {"area_id": area_id})
        msg_id += 1

    for area_id, icon in desired_icons.items():
        current_icon = (existing_areas.get(area_id) or {}).get("icon")
        if current_icon == icon:
            print(f"  OK   area icon {area_id!r} already {icon}")
            continue

        await ws.send(
            json.dumps(
                {
                    "id": msg_id,
                    "type": "config/area_registry/update",
                    "area_id": area_id,
                    "icon": icon,
                }
            )
        )
        update_resp = json.loads(await ws.recv())
        ok = update_resp.get("success", False)
        print(f"  {'ICON' if ok else 'FAIL'} {area_id!r} → {icon}")
        msg_id += 1

    return msg_id


async def _sync_areas_aiohttp(ws, desired_areas, desired_icons, id_start):
    """Create missing areas and apply area icons via aiohttp."""
    await ws.send_json({"id": id_start, "type": "config/area_registry/list"})
    resp = await ws.receive_json()
    existing_areas = {a["area_id"]: a for a in resp["result"]}

    msg_id = id_start + 1
    all_area_ids = sorted(set(desired_areas) | set(desired_icons))

    for area_id in all_area_ids:
        if area_id in existing_areas:
            continue

        payload = {
            "id": msg_id,
            "type": "config/area_registry/create",
            "name": area_id,
        }
        if area_id in desired_icons:
            payload["icon"] = desired_icons[area_id]

        await ws.send_json(payload)
        create_resp = await ws.receive_json()
        ok = create_resp.get("success", False)
        print(f"  {'CREATE' if ok else 'FAIL'} area {area_id!r}")
        if ok:
            existing_areas[area_id] = create_resp.get("result", {"area_id": area_id})
        msg_id += 1

    for area_id, icon in desired_icons.items():
        current_icon = (existing_areas.get(area_id) or {}).get("icon")
        if current_icon == icon:
            print(f"  OK   area icon {area_id!r} already {icon}")
            continue

        await ws.send_json(
            {
                "id": msg_id,
                "type": "config/area_registry/update",
                "area_id": area_id,
                "icon": icon,
            }
        )
        update_resp = await ws.receive_json()
        ok = update_resp.get("success", False)
        print(f"  {'ICON' if ok else 'FAIL'} {area_id!r} → {icon}")
        msg_id += 1

    return msg_id


async def _apply_devices_websockets(ws, devices, desired_areas, id_start):
    """Send device area updates via websockets."""
    msg_id = id_start
    name_to_device = {d["name_by_user"] or d["name"]: d for d in devices}

    updates = 0
    for area_id, names in desired_areas.items():
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

    print(f"Done: {updates} device update(s)")


async def _apply_devices_aiohttp(ws, devices, desired_areas, id_start):
    """Send device area updates via aiohttp."""
    msg_id = id_start
    name_to_device = {d["name_by_user"] or d["name"]: d for d in devices}

    updates = 0
    for area_id, names in desired_areas.items():
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

    print(f"Done: {updates} device update(s)")


def main():
    devices_yaml = sys.argv[1] if len(sys.argv) > 1 else "/var/lib/hass/devices.yaml"
    desired_areas, desired_icons = load_devices_yaml(devices_yaml)
    print(
        f"Loaded {sum(len(v) for v in desired_areas.values())} device assignments and "
        f"{len(desired_icons)} area icons from {devices_yaml}"
    )

    token = generate_token()

    if websockets is not None:
        asyncio.run(apply_with_websockets(token, desired_areas, desired_icons))
    else:
        asyncio.run(apply_with_aiohttp(token, desired_areas, desired_icons))


if __name__ == "__main__":
    main()
