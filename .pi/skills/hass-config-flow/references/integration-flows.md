# Integration Config Flow Reference

How each integration behaves when added via the REST API.

## Auto-discovery (no config needed)

| Integration | Domain       | Notes                                      |
| ----------- | ------------ | ------------------------------------------ |
| Google Cast | `cast`       | Discovers Chromecast devices on LAN        |
| Mobile App  | `mobile_app` | Auto-registers when companion app connects |

## Local network required (same L2)

| Integration        | Domain               | Flow steps                            |
| ------------------ | -------------------- | ------------------------------------- |
| HomeKit Controller | `homekit_controller` | Select device → enter pairing code    |
| Apple TV           | `apple_tv`           | Enter device name/IP → pair on device |
| Samsung TV         | `samsungtv`          | Enter IP → accept on TV screen        |

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
```
