# ZHA Zigbee mesh

Zigbee Home Automation (ZHA) via the Nabu Casa ZBT-2 USB dongle. All other smart-home devices in this setup are Matter/Thread — ZHA is the only Zigbee path.

## Radio

- Coordinator: Nabu Casa ZBT-2 (Home Assistant Connect)
- Radio type: ezsp (Silicon Labs EmberZNet)
- Device path: `/dev/zbt2` → `/dev/ttyACM0` (udev rule in `default.nix`)
- Config entry source: `user`, not disabled

## Mesh topology

The ZBT-2 coordinator is a full-time radio but Zigbee **end devices** (battery-powered sleepy devices like the Aqara mini switch) cannot route for themselves. A network with only a coordinator and sleepy end devices is fragile: end devices may fail to join or drop off when they can't reach the coordinator directly.

**A mains-powered router must be on the network before pairing sleepy end devices.** The SONOFF S31 Lite zb smart plug (first device paired) serves as the router. Pair routers first, then end devices.

## Pairing

1. HA UI: Settings → Devices & Services → ZHA → Configure → Add devices
2. Hold the device's pair button ~10 seconds until its LED blinks (Aqara mini switch). Some Aqara variants use 5 quick presses instead — try both if one doesn't work.
3. Wait for "Device found". Interview and entity creation happen automatically.

If a device doesn't join within 30 seconds, release, wait 5 seconds, and repeat. Aqara devices often need 2–3 attempts.

## Troubleshooting: device won't join

1. **No router on the network** — the most common cause for sleepy end devices. Verify a mains-powered router is paired and online before pairing battery-powered devices.
2. **Dongle not enumerated** — check `ls -l /dev/zbt2` on the NUC. If missing, the ZBT-2 isn't connected (USB port/cable/power).
3. **ZHA config entry greyed out** — radio didn't initialize. Check HA logs: Settings → System → Logs, filter `bellows` or `zha`.
4. **Weak battery** — transmits too weakly to join even if button presses register.
5. **Distance** — pair in the same room as the NUC or a router, then relocate.

## Devices

| Device                     | Role      | IEEE                    | Notes                                       |
| -------------------------- | --------- | ----------------------- | ------------------------------------------- |
| SONOFF S31 Lite zb         | Router    | 00:12:4b:00:23:ab:fa:4c | First device; `switch.kitchen_dog_fountain` |
| Aqara Wireless Mini Switch | EndDevice | 00:15:8d:00:07:06:b7:6f | `lumi.remote.b1acn01`, quirk `SwitchAQ3B`   |

## Aqara mini switch events

The Aqara mini switch (`lumi.remote.b1acn01`) fires ZHA device events on press. No automation is wired yet — when adding one, use a ZHA device trigger in a `_domains/` domain file with `ensureEnabled`.
