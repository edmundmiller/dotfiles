---
name: hass-config-flow
description: >
  Interact with Home Assistant via the REST API on a NixOS host.
  Use when adding integrations, querying entities, managing config
  flows, creating API tokens, or automating HA setup programmatically.
  Trigger phrases: "add HA integration", "configure home assistant",
  "query HA entities", "create HA token", "HA REST API",
  "pair homekit", "set up matter in HA", "add spotify to HA".
---

# Home Assistant REST API

Docs: https://developers.home-assistant.io/docs/api/rest/

NixOS `extraComponents` bundles integration code, but config-flow-only
integrations (Spotify, Matter, HomeKit Controller, Cast, etc.) require
the REST API or UI to complete setup.

## Token generation

HA long-lived tokens are HS256 JWTs signed with a per-token key stored
in `/var/lib/hass/.storage/auth`. Generate one without external deps:

```bash
ssh nuc "sudo python3 << 'PY'
import hashlib, hmac, base64, time, json

auth = json.load(open('/var/lib/hass/.storage/auth'))
for t in auth['data']['refresh_tokens']:
    if t.get('client_name') == 'agent-automation':
        header = base64.urlsafe_b64encode(json.dumps({'alg':'HS256','typ':'JWT'}).encode()).rstrip(b'=')
        now = int(time.time())
        payload = base64.urlsafe_b64encode(json.dumps({'iss':t['id'],'iat':now,'exp':now+86400*365}).encode()).rstrip(b'=')
        sig_input = header + b'.' + payload
        sig = base64.urlsafe_b64encode(hmac.new(t['jwt_key'].encode(), sig_input, hashlib.sha256).digest()).rstrip(b'=')
        print((sig_input + b'.' + sig).decode())
        break
PY"
```

If no `agent-automation` token exists yet, create one via the HA UI:
**Profile → Security → Long-Lived Access Tokens → Create Token** (name it `agent-automation`).

Verify: `curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8123/api/`
→ `{"message":"API running."}`

## API quick reference

All requests to `http://127.0.0.1:8123` with header `Authorization: Bearer $TOKEN`.

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

## Common workflows

### Add a config-flow integration

```bash
# 1. Start the flow
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"handler":"spotify"}' http://127.0.0.1:8123/api/config/config_entries/flow

# Response types:
#   "form"         → needs input, check "data_schema" for fields
#   "create_entry" → done
#   "abort"        → can't proceed (reason in "reason" field)

# 2. Submit form data (if type=form)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"field": "value"}' \
  http://127.0.0.1:8123/api/config/config_entries/flow/{flow_id}
```

### OAuth integrations (Spotify, Google, etc.)

These return `abort` with `reason: missing_credentials` until app credentials are registered:

```bash
# 1. Register OAuth app credentials
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"domain":"spotify","client_id":"YOUR_ID","client_secret":"YOUR_SECRET"}' \
  http://127.0.0.1:8123/api/config/application_credentials

# 2. Then start config flow — it will return an auth URL for the user to visit
```

### List all configured integrations

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8123/api/config/config_entries/entry \
  | python3 -c "
import json, sys
for e in json.load(sys.stdin):
    print(f'{e[\"state\"]:12} {e[\"domain\"]:25} {e[\"title\"]}')
"
```

### Call a service

```bash
# Turn off TV
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id":"media_player.tv"}' \
  http://127.0.0.1:8123/api/services/media_player/turn_off

# Set house mode
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"entity_id":"input_select.house_mode","option":"Movie"}' \
  http://127.0.0.1:8123/api/services/input_select/select_option
```

### Query entity state

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8123/api/states/input_select.house_mode \
  | python3 -m json.tool
```

## Integration-specific notes

### Spotify

- Needs OAuth app at https://developer.spotify.com/dashboard
- Redirect URI: `https://homeassistant.cinnamon-rooster.ts.net/auth/external/callback`
- Register credentials via `/api/config/application_credentials` before starting flow

### Matter

- Needs `services.matter-server` running (port 5580)
- Flow asks for URL, default: `ws://localhost:5580/ws`

### HomeKit Controller

- Auto-discovers via mDNS; flow: select device → enter pairing code
- Homebridge pin: `sudo cat /var/lib/homebridge/config.json | jq .bridge.pin`

### Google Cast

- No config needed — auto-discovers Chromecast devices

### Apple TV / Samsung TV

- Must be powered on and on same L2 network (not over Tailscale)
- Discover: `avahi-browse -trp _mediaremotetv._tcp` / `_samsungtvs._tcp`

### Mobile App

- Cannot be added via API — auto-registers when companion app connects

## NixOS context

- HA config: `/var/lib/hass/` on NUC
- Auth storage: `/var/lib/hass/.storage/auth`
- Config entries: `/var/lib/hass/.storage/core.config_entries`
- API only on localhost (`127.0.0.1:8123`), HTTPS via Tailscale serve
- Public URL: `https://homeassistant.cinnamon-rooster.ts.net/`
- NixOS option `services.home-assistant.defaultIntegrations` auto-loads:
  automation, scene, script, input_boolean, input_button, input_datetime,
  input_number, input_select, input_text, counter, timer, schedule, person,
  zone, tag, backup — no `extraComponents` needed for these
