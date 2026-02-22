# Identifying Device Protocols in Home Assistant

## The fast answer: check `identifiers` in the device registry

The `identifiers` field on every device is a list of `[namespace, id]` pairs.
The namespace tells you the protocol:

| Namespace            | Protocol          | Notes                                   |
| -------------------- | ----------------- | --------------------------------------- |
| `matter`             | Matter / Thread   | Thread is transport, Matter is protocol |
| `zha`                | Zigbee            | Via ZHA integration                     |
| `deconz`             | Zigbee            | Via deCONZ/Phoscon                      |
| `mqtt`               | Zigbee2MQTT       | Via Zigbee2MQTT bridge                  |
| `homekit_controller` | HomeKit (BLE/IP)  | Native HomeKit or via Homebridge        |
| `apple_tv`           | Apple ATV/HomePod | Apple devices                           |

```json
"identifiers": [
  ["matter", "serial_3RM01-4385-00162"],
  ["matter", "deviceid_15F0AB97017D95BD-..."]
]
```

→ Matter device. Do NOT try to move it to ZHA.

```json
"identifiers": [
  ["zha", "00:12:4b:00:...:ff:fe:ab:cd"]
]
```

→ Zigbee device on ZHA.

## Query via hass-cli

```bash
# List all devices with their identifier namespaces
HASS_TOKEN=<token> HASS_SERVER=http://localhost:8123 \
  hass-cli -o json device list | python3 -c "
import json, sys
for d in json.load(sys.stdin):
    name = d.get('name_by_user') or d.get('name') or '?'
    protos = {i[0] for i in (d.get('identifiers') or [])}
    print(f'{name:40s}  {protos}')
"
```

## Common vendor model-name conventions

| Suffix / keyword | Meaning        |
| ---------------- | -------------- |
| `-W`             | Wi-Fi + Matter |
| `-Z`             | Zigbee         |
| `-T`             | Thread         |
| `ZBT`, `ZB`      | Zigbee         |
| `Thread`, `TH`   | Thread         |
| `Matter`         | Matter         |

Examples:

- ThirdReality **Smart Night Light-W** → Matter (Wi-Fi)
- ThirdReality **Smart Plug-Z** → Zigbee
- Nanoleaf **Essentials A19** → Thread/Matter (paired via HomePod/Apple TV)

## Matter vs Thread — not the same thing

- **Thread** is a low-power mesh radio protocol (like Zigbee physically)
- **Matter** is the application protocol that runs _over_ Thread (or Wi-Fi or Ethernet)
- A "Thread device" is always a Matter device — its HA identifiers use namespace `matter`
- Thread devices don't appear under a Thread config entry; they appear under the `matter` config entry
- The `thread` config entry in HA is just the Thread border router management, not devices

## Decision tree: move to ZHA?

```
identifiers namespace == "zha" or "deconz" or "mqtt"?
  → Already on Zigbee, no action needed

identifiers namespace == "matter"?
  → Already on Matter/Thread, leave it alone (ZBT-2 Thread radio already serves it)

identifiers namespace == "homekit_controller"?
  → Check if the device is a native HomeKit device (BLE/IP) or a Zigbee device
    behind a Homebridge Zigbee plugin
  → If native HomeKit: leave as-is
  → If Zigbee via Homebridge: candidate for ZHA migration (remove from Homebridge, re-pair)

No identifiers, or config_entry is Homebridge?
  → Investigate further; check manufacturer docs for actual radio protocol
```

## Checking what's on Homebridge vs native

If `primary_config_entry` matches the `homekit_controller` entry for Homebridge
(not a direct HomeKit device), the device is going through Homebridge. To tell if
it's Zigbee underneath, check Homebridge plugins:

```bash
ssh nuc "cat /var/lib/homebridge/config.json | python3 -c \"
import json,sys; cfg=json.load(sys.stdin)
for p in cfg.get('platforms',[]): print(p.get('platform'), p.get('name',''))
for a in cfg.get('accessories',[]): print(a.get('accessory'), a.get('name',''))
\""
```
