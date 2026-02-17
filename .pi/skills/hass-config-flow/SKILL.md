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

## Scripts

All scripts run on the NUC (via SSH). They need `TOKEN` env var unless noted.

| Script               | Purpose                                  | Usage                                               |
| -------------------- | ---------------------------------------- | --------------------------------------------------- |
| `ha-token.sh`        | Generate JWT from existing auth token    | `sudo bash ha-token.sh [token_name]`                |
| `ha-api.sh`          | General-purpose API wrapper              | `ha-api.sh GET /api/states/input_select.house_mode` |
| `ha-entities.sh`     | List entities, optionally by domain      | `ha-entities.sh media_player`                       |
| `ha-integrations.sh` | List all configured integrations         | `ha-integrations.sh`                                |
| `ha-call.sh`         | Call a service on an entity              | `ha-call.sh media_player.turn_off media_player.tv`  |
| `ha-flow.sh`         | Manage config flows (start/submit/abort) | `ha-flow.sh start spotify`                          |

### Quick start

```bash
# 1. Get a token (no HA restart needed)
TOKEN=$(ssh nuc "sudo bash /path/to/ha-token.sh")

# 2. Use any script
ssh nuc "TOKEN=$TOKEN bash /path/to/ha-entities.sh media_player"
ssh nuc "TOKEN=$TOKEN bash /path/to/ha-call.sh media_player.turn_off media_player.tv"
ssh nuc "TOKEN=$TOKEN bash /path/to/ha-flow.sh start spotify"
```

## References

Read these for detailed information:

| File                                 | Contents                                                                     |
| ------------------------------------ | ---------------------------------------------------------------------------- |
| `references/integration-flows.md`    | Per-integration config flow behavior, abort reasons, mDNS discovery commands |
| `references/default-integrations.md` | NixOS `defaultIntegrations` list — what's auto-loaded, Nix config examples   |

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
