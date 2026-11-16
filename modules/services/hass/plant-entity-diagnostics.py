#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["websockets>=15,<17"]
# ///
"""Read plant power controls by registry device membership, without live changes."""

from datetime import datetime, timezone
import json
from pathlib import Path
import sys

from websockets.sync.client import connect

ANCHORS = {
    "top_two_levels": "button.living_room_top_plant_light_identify",
    "bottom_level": "switch.plant_glow_light",
}


def request(socket, request_id, command):
    socket.send(json.dumps({"id": request_id, "type": command}))
    reply = json.loads(socket.recv(timeout=10))
    if (reply.get("id") != request_id or reply.get("type") != "result"
            or not reply.get("success")):
        raise ValueError("Registry read failed")
    return reply["result"]


def main():
    token = Path("/run/agenix/ha-hermes-token").read_text().strip()
    with connect("ws://127.0.0.1:8123/api/websocket", open_timeout=10,
                 close_timeout=1, max_size=16 * 1024 * 1024, proxy=None) as socket:
        if json.loads(socket.recv(timeout=10)).get("type") != "auth_required":
            raise ValueError("Unexpected handshake")
        socket.send(json.dumps({"type": "auth", "access_token": token}))
        if json.loads(socket.recv(timeout=10)).get("type") != "auth_ok":
            raise ValueError("Authentication failed")
        entities = request(socket, 1, "config/entity_registry/list")
        devices = request(socket, 2, "config/device_registry/list")
        states = request(socket, 3, "get_states")

    entities_by_id = {entity["entity_id"]: entity for entity in entities}
    devices_by_id = {device["id"]: device for device in devices}
    states_by_id = {state["entity_id"]: state for state in states}
    result = {"observed_at": datetime.now(timezone.utc).isoformat(), "plants": {}}
    anchor_devices = []
    for role, anchor_id in ANCHORS.items():
        device_id = entities_by_id[anchor_id]["device_id"]
        if not device_id:
            raise ValueError("Anchor has no device")
        anchor_devices.append(device_id)
        device = devices_by_id[device_id]
        controls = []
        for entity in sorted(entities, key=lambda item: item["entity_id"]):
            entity_id = entity["entity_id"]
            if (entity.get("device_id") != device_id
                    or entity_id.split(".", 1)[0] not in {"light", "switch"}):
                continue
            state = states_by_id.get(entity_id, {})
            controls.append({
                "entity_id": entity_id,
                "name": entity.get("name") or entity.get("original_name"),
                "friendly_name": state.get("attributes", {}).get("friendly_name"),
                "disabled_by": entity.get("disabled_by"),
                "state": state.get("state", "missing"),
            })
        result["plants"][role] = {
            "anchor_entity_id": anchor_id,
            "device_name": device.get("name_by_user") or device.get("name"),
            "controls": controls,
        }
    result["same_device"] = anchor_devices[0] == anchor_devices[1]
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(json.dumps({"status": "unknown", "error_type": type(error).__name__}))
        sys.exit(2)
