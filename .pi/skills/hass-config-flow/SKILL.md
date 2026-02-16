---
name: hass-config-flow
description: >
  Configure Home Assistant integrations via the REST API on a NixOS host.
  Use when adding HA integrations programmatically, creating long-lived
  access tokens, or managing config flows without the UI. Trigger phrases:
  "add HA integration", "configure home assistant", "pair homekit",
  "set up matter in HA", "add integration via API".
---

# Home Assistant Config Flow via API

NixOS Home Assistant uses `extraComponents` to bundle integration code, but
config-flow-only integrations (Matter, HomeKit Controller, Apple TV, Samsung TV,
Cast, etc.) cannot be added via `configuration.yaml` — they require the config
flow API.

## Prerequisites

- `services.home-assistant` enabled with desired `extraComponents`
- SSH access to the NixOS host
- HA running and accessible on localhost

## Workflow

### 1) Create a long-lived access token

HA tokens are JWTs signed with a per-token key stored in `/var/lib/hass/.storage/auth`.
Use `scripts/create-ha-token.sh` on the NixOS host:

```bash
scp scripts/create-ha-token.sh nuc:/tmp/
ssh nuc "sudo bash /tmp/create-ha-token.sh"
# Outputs: TOKEN=eyJ...
```

The script:

1. Stops HA
2. Injects a refresh token into auth storage
3. Generates a JWT signed with the token's key
4. Restarts HA
5. Verifies the token works

### 2) Add integrations via config flow

Use `scripts/ha-add-integration.sh`:

```bash
# Matter (connects to local matter-server)
ssh nuc "TOKEN=eyJ... bash /tmp/ha-add-integration.sh matter"

# HomeKit Controller (auto-discovers, needs pairing code)
ssh nuc "TOKEN=eyJ... bash /tmp/ha-add-integration.sh homekit_controller"

# Google Cast (auto-discovery, no config needed)
ssh nuc "TOKEN=eyJ... bash /tmp/ha-add-integration.sh cast"

# Samsung TV (needs host IP)
ssh nuc "TOKEN=eyJ... bash /tmp/ha-add-integration.sh samsungtv 192.168.1.x"

# Apple TV (needs device name or IP on local network)
ssh nuc "TOKEN=eyJ... bash /tmp/ha-add-integration.sh apple_tv 'Living Room'"
```

### 3) Verify

```bash
TOKEN=eyJ...
ssh nuc "curl -s -H 'Authorization: Bearer $TOKEN' \
  http://127.0.0.1:8123/api/config/config_entries/entry" \
  | python3 -c "
import json, sys
for e in json.load(sys.stdin):
    print(f\"  {e['state']:10} {e['domain']:25} {e['title']}\")
"
```

## Config flow API reference

All endpoints are on `http://127.0.0.1:8123` with `Authorization: Bearer $TOKEN`.

| Action       | Method | Endpoint                                                       |
| ------------ | ------ | -------------------------------------------------------------- |
| Start flow   | POST   | `/api/config/config_entries/flow` with `{"handler": "domain"}` |
| Submit step  | POST   | `/api/config/config_entries/flow/{flow_id}` with step data     |
| Abort flow   | DELETE | `/api/config/config_entries/flow/{flow_id}`                    |
| List entries | GET    | `/api/config/config_entries/entry`                             |
| Delete entry | DELETE | `/api/config/config_entries/entry/{entry_id}`                  |

Flow responses have `type`: `form` (needs input), `create_entry` (done), `abort` (can't proceed).

## Integration-specific notes

### Matter

- Needs `services.matter-server` running (port 5580)
- Config flow asks for URL, default: `ws://localhost:5580/ws`

### HomeKit Controller

- Auto-discovers HomeKit/Homebridge devices via mDNS
- Flow: select device → enter pairing code
- Homebridge pin is in `/var/lib/homebridge/config.json` under `bridge.pin`

### Apple TV / Samsung TV

- Require device to be powered on and discoverable via mDNS on local LAN
- Won't work over Tailscale — needs same L2 network
- Apple TV: `avahi-browse -trp _mediaremotetv._tcp` to find devices
- Samsung TV: `avahi-browse -trp _samsungtvs._tcp`

### Mobile App

- Cannot be added via API — auto-registers when HA companion app connects

### Google Cast

- No required config — `known_hosts: []` enables auto-discovery
