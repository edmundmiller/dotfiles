# Integration Config Flow Reference

How each integration behaves when added via the REST API.

## Auto-discovery (no config needed)

| Integration | Domain       | Notes                                      |
| ----------- | ------------ | ------------------------------------------ |
| Google Cast | `cast`       | Discovers Chromecast devices on LAN        |
| Mobile App  | `mobile_app` | Auto-registers when companion app connects |

## Local network required (same L2)

| Integration          | Domain               | Flow steps                                                      |
| -------------------- | -------------------- | --------------------------------------------------------------- |
| HomeKit Controller   | `homekit_controller` | Select device → enter pairing code                              |
| Apple TV             | `apple_tv`           | Enter device name/IP → pair on device                           |
| Samsung TV           | `samsungtv`          | Enter IP → accept on TV screen                                  |
| iRobot Roomba/Braava | `roomba`             | Manual IP → link (auto-retrieve) → link_manual (enter password) |

## OAuth (needs app credentials first)

These abort with `missing_credentials` until you register credentials:

```bash
TOKEN=... ha-api.sh POST /api/config/application_credentials \
  '{"domain":"DOMAIN","client_id":"ID","client_secret":"SECRET"}'
```

| Integration | Domain    | Developer Portal                                 | Redirect URI                                                           |
| ----------- | --------- | ------------------------------------------------ | ---------------------------------------------------------------------- |
| Spotify     | `spotify` | https://developer.spotify.com/dashboard          | `https://homeassistant.cinnamon-rooster.ts.net/auth/external/callback` |
| Google      | `google`  | https://console.cloud.google.com                 | `https://homeassistant.cinnamon-rooster.ts.net/auth/external/callback` |
| Ecobee      | `ecobee`  | https://www.ecobee.com/consumerportal/index.html | (uses PIN-based flow)                                                  |

## Server-to-server

| Integration | Domain   | Flow data                           |
| ----------- | -------- | ----------------------------------- |
| Matter      | `matter` | `{"url": "ws://localhost:5580/ws"}` |
| MQTT        | `mqtt`   | `{"broker":"host","port":1883,...}` |

## Common abort reasons

| Reason                    | Meaning                                       | Fix                                                |
| ------------------------- | --------------------------------------------- | -------------------------------------------------- |
| `missing_credentials`     | OAuth integration needs app credentials first | Register via `/api/config/application_credentials` |
| `already_configured`      | Integration already set up                    | Delete existing entry first                        |
| `no_devices_found`        | mDNS discovery found nothing                  | Check device is on, same network                   |
| `reauth_required`         | Token expired                                 | Re-authenticate via UI or API                      |
| `single_instance_allowed` | Only one instance permitted                   | Already configured                                 |

## Discovering devices

```bash
# HomeKit devices
avahi-browse -trp _hap._tcp

# Apple TV
avahi-browse -trp _mediaremotetv._tcp

# Samsung TV
avahi-browse -trp _samsungtvs._tcp

# Google Cast
avahi-browse -trp _googlecast._tcp

# MQTT brokers
avahi-browse -trp _mqtt._tcp

# iRobot Roomba/Braava (port 8883 = iRobot MQTT-TLS)
for ip in $(ip neigh | grep -E 'REACHABLE|STALE' | awk '{print $1}' | grep '192.168'); do
  timeout 2 bash -c "echo >/dev/tcp/$ip/8883" 2>/dev/null && echo "iROBOT: $ip"
done
```

## iRobot Roomba/Braava (detailed)

### Credential retrieval

iRobot robots need a BLID (username) and password. Three methods:

**1. Cloud retrieval (recommended, works for all models including J7/i7/m6):**

```bash
# Install dorita980 globally
npm install -g dorita980

# Retrieve credentials — uses iRobot cloud API
# 1Password: op://Moni and Ed/iRobot/{username,password}
get-roomba-password-cloud <irobot_email> <irobot_password>
```

Output contains BLID and password for every robot on the account.

**2. Local retrieval via roombapy (built into HA, older models only):**

```bash
# From HA container
docker exec -it homeassistant python -c \
  'import roombapy.entry_points; roombapy.entry_points.password()' <ROOMBA_IP>

# NixOS native HA
sudo -u hass python3 -c \
  'import roombapy.entry_points; roombapy.entry_points.password()' <ROOMBA_IP>
```

**3. Auto-retrieve via HA flow** (requires physical button press on robot).

### Config flow steps (REST API)

The Roomba flow does UDP discovery first — **needs long curl timeouts (~120s)**.

```bash
# 1. Start flow (triggers mDNS discovery, often fails — falls through to manual)
curl -s --max-time 120 -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"handler": "roomba"}' \
  http://localhost:8123/api/config/config_entries/flow
# Returns: step_id=manual, flow_id=<ID>

# 2. Submit robot IP
curl -s --max-time 120 -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"host": "<ROBOT_IP>"}' \
  http://localhost:8123/api/config/config_entries/flow/<FLOW_ID>
# Returns: step_id=link (shows robot name + BLID)

# 3. Skip auto-retrieve (submit empty — will fail, goes to link_manual)
curl -s --max-time 30 -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  http://localhost:8123/api/config/config_entries/flow/<FLOW_ID>
# Returns: step_id=link_manual

# 4. Submit password from dorita980
curl -s --max-time 60 -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"password": "<PASSWORD_FROM_DORITA980>"}' \
  http://localhost:8123/api/config/config_entries/flow/<FLOW_ID>
# Returns: type=create_entry (success!)
```

### Gotchas

- **Close the iRobot app** on all devices before connecting — Roomba MQTT allows only one connection
- Discovery uses ALL_ATTEMPTS=2, HOST_ATTEMPTS=6, ROOMBA_WAKE_TIME=6s — curl needs ≥120s timeout
- `setup_retry` after create_entry is normal; HA retries until MQTT connects
- Repeat the full flow for each robot (one flow per device)
