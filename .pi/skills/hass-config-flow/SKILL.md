---
name: hass-config-flow
description: >
  Interact with Home Assistant via the REST API on a NixOS host.
  Use when adding integrations, querying entities, managing config
  flows, creating API tokens, or automating HA setup programmatically.
  Also covers identifying device protocols (Matter, Zigbee, Thread,
  HomeKit) from the device registry.
  Trigger phrases: "add HA integration", "configure home assistant",
  "query HA entities", "create HA token", "HA REST API",
  "pair homekit", "set up matter in HA", "add spotify to HA",
  "is this device zigbee or thread", "what protocol is this device",
  "move devices to ZHA", "identify matter devices".
---

# Home Assistant REST API

Docs: https://developers.home-assistant.io/docs/api/rest/

NixOS `extraComponents` bundles integration code, but config-flow-only
integrations (Spotify, Matter, HomeKit Controller, Cast, etc.) require
the REST API or UI to complete setup.

## hass-cli (preferred for inspection/simple calls)

`home-assistant-cli` is installed on the NUC. Prefer it over raw curl for
entity listing, service calls, device/area management, and event watching.

```bash
# On NUC (after getting a token):
export HASS_SERVER=http://localhost:8123
export HASS_TOKEN=<token>

hass-cli state list 'light.*'          # list entities by glob
hass-cli state get light.office        # get single entity (yaml)
hass-cli service call homeassistant.toggle --arguments entity_id=light.office
hass-cli device list                   # all devices with area
hass-cli area list                     # all areas
hass-cli device assign Kitchen --match "Kitchen Light"  # bulk assign area
hass-cli event watch                   # watch all events
hass-cli event watch deconz_event      # watch specific event type
hass-cli -o yaml state list            # yaml output
hass-cli -o json state list 'light.*' | jq '[.[] | {entity: .entity_id, name: .attributes.friendly_name, state: .state}]'
hass-cli -o json state list 'light.*' | python3 -c "import json,sys; d=json.load(sys.stdin); print([x['entity_id'] for x in d if x['state']=='on'])"
```

**Note:** `hass-cli info` is broken on current HA (deprecated endpoint). All other commands work.

Use raw curl (below) for config flows, app credentials, and anything hass-cli doesn't cover.

## Querying the API (inline SSH)

Scripts in `scripts/` exist but are local — they can't be referenced by
path on the NUC. Use inline SSH commands instead.

### Get a token

```bash
TOKEN=$(ssh nuc "sudo python3 -c '
import hashlib, hmac, base64, time, json
auth = json.load(open(\"/var/lib/hass/.storage/auth\"))
for t in auth[\"data\"][\"refresh_tokens\"]:
    if t.get(\"client_name\") == \"agent-automation\":
        header = base64.urlsafe_b64encode(json.dumps({\"alg\":\"HS256\",\"typ\":\"JWT\"}).encode()).rstrip(b\"=\")
        now = int(time.time())
        payload = base64.urlsafe_b64encode(json.dumps({\"iss\":t[\"id\"],\"iat\":now,\"exp\":now+86400*365}).encode()).rstrip(b\"=\")
        sig_input = header + b\".\" + payload
        sig = base64.urlsafe_b64encode(hmac.new(t[\"jwt_key\"].encode(), sig_input, hashlib.sha256).digest()).rstrip(b\"=\")
        print((sig_input + b\".\" + sig).decode())
        break
'" 2>/dev/null)
```

### List entities (by domain)

```bash
ssh nuc "curl -s -H 'Authorization: Bearer $TOKEN' http://localhost:8123/api/states" | python3 -c "
import json, sys
states = json.load(sys.stdin)
for s in sorted(states, key=lambda x: x['entity_id']):
    eid = s['entity_id']
    name = s['attributes'].get('friendly_name', '')
    domain = eid.split('.')[0]
    if domain in ('light', 'switch', 'cover', 'media_player', 'fan', 'binary_sensor', 'scene', 'humidifier'):
        print(f'{eid:55s} {name}')
"
```

Change the `domain in (...)` filter as needed, or remove it for all entities.

### Call a service

```bash
ssh nuc "curl -s -X POST -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"entity_id\": \"media_player.tv\"}' \
  http://localhost:8123/api/services/media_player/turn_off"
```

### Start a config flow

```bash
ssh nuc "curl -s -X POST -H 'Authorization: Bearer $TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{\"handler\": \"spotify\"}' \
  http://localhost:8123/api/config/config_entries/flow"
```

### Helper scripts (reference)

Scripts in `scripts/` are useful as reference for the API patterns but
must be piped via SSH or inlined — they aren't deployed to the NUC.

| Script               | Purpose                            |
| -------------------- | ---------------------------------- |
| `ha-token.sh`        | Generate JWT from auth storage     |
| `ha-api.sh`          | General-purpose API wrapper        |
| `ha-entities.sh`     | List entities by domain            |
| `ha-integrations.sh` | List configured integrations       |
| `ha-call.sh`         | Call a service on an entity        |
| `ha-flow.sh`         | Manage config flows (start/submit) |

## References

Read these for detailed information:

| File                                 | Contents                                                                                                                                     |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `references/integration-flows.md`    | Per-integration config flow behavior, abort reasons, mDNS discovery commands                                                                 |
| `references/default-integrations.md` | NixOS `defaultIntegrations` list — what's auto-loaded, Nix config examples                                                                   |
| `references/device-protocols.md`     | Identify device protocol (Matter/Zigbee/Thread/HomeKit) from device registry; vendor model-name conventions; decision tree for ZHA migration |

## Token generation

HA long-lived tokens are HS256 JWTs signed with a per-token key in
`/var/lib/hass/.storage/auth`. Use `scripts/ha-token.sh` or inline:

```bash
ssh nuc "sudo bash ha-token.sh"           # uses "agent-automation" token
ssh nuc "sudo bash ha-token.sh my-token"  # use a different token name
```

If no token exists yet, create via HA UI:
**Profile → Security → Long-Lived Access Tokens → Create Token**

Verify: `curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8123/api/`
→ `{"message":"API running."}`

## API quick reference

All requests to `http://127.0.0.1:8123` with `Authorization: Bearer $TOKEN`.

| Action              | Method | Endpoint                                      | Body                                                       |
| ------------------- | ------ | --------------------------------------------- | ---------------------------------------------------------- |
| Health check        | GET    | `/api/`                                       | —                                                          |
| HA config           | GET    | `/api/config`                                 | —                                                          |
| List states         | GET    | `/api/states`                                 | —                                                          |
| Get entity state    | GET    | `/api/states/{entity_id}`                     | —                                                          |
| Set entity state    | POST   | `/api/states/{entity_id}`                     | `{"state": "...", "attributes": {...}}`                    |
| Fire event          | POST   | `/api/events/{event_type}`                    | `{...event_data}`                                          |
| Call service        | POST   | `/api/services/{domain}/{service}`            | `{"entity_id": "..."}` + service data                      |
| List services       | GET    | `/api/services`                               | —                                                          |
| List config entries | GET    | `/api/config/config_entries/entry`            | —                                                          |
| Start config flow   | POST   | `/api/config/config_entries/flow`             | `{"handler": "domain"}`                                    |
| Submit flow step    | POST   | `/api/config/config_entries/flow/{flow_id}`   | step-specific data                                         |
| Abort flow          | DELETE | `/api/config/config_entries/flow/{flow_id}`   | —                                                          |
| Delete config entry | DELETE | `/api/config/config_entries/entry/{entry_id}` | —                                                          |
| Add app credentials | POST   | `/api/config/application_credentials`         | `{"domain":"...","client_id":"...","client_secret":"..."}` |
| Render template     | POST   | `/api/template`                               | `{"template": "{{ states('...') }}"}`                      |
| Check config        | POST   | `/api/config/core/check_config`               | —                                                          |

## Key workflows

### Config flow (non-OAuth)

```bash
ha-flow.sh start cast           # auto-discovery, usually creates entry immediately
ha-flow.sh start matter         # returns form → submit with URL
ha-flow.sh submit <flow_id> '{"url":"ws://localhost:5580/ws"}'
```

### OAuth integrations (Spotify, Google, etc.)

1. Register app credentials first (abort reason: `missing_credentials`)
2. Start config flow — returns auth URL for user

```bash
ha-api.sh POST /api/config/application_credentials \
  '{"domain":"spotify","client_id":"ID","client_secret":"SECRET"}'
ha-flow.sh start spotify
```

See `references/integration-flows.md` for per-integration details.

## NixOS context

- Auth storage: `/var/lib/hass/.storage/auth`
- API: `http://127.0.0.1:8123` (localhost only), HTTPS via Tailscale serve
- Public URL: `https://homeassistant.cinnamon-rooster.ts.net/`
- `defaultIntegrations` auto-loads input helpers, automation, scene, script,
  etc. — see `references/default-integrations.md`
