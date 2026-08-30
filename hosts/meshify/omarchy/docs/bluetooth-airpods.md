---
purpose: Recover meshify Bluetooth and connect its AirPods through BlueZ, PipeWire, and Omapods.
applies_to: A stale Bluetooth widget, stuck AirPods pairing, audio routing, or switching AirPods models.
entrypoint: Verify adapter power with `omarchy bluetooth power is-on` and `bluetoothctl show`.
verification: Confirm BlueZ connection, PipeWire routing, and a connected librepods status snapshot.
update_when: Omarchy Bluetooth helpers, the USB adapter, AirPods models, PipeWire, or Omapods behavior changes.
---

# Bluetooth and AirPods recovery

Meshify uses a TP-Link USB Bluetooth adapter. AirPods recovery crosses four
independent layers:

1. BlueZ owns adapter power, pairing, trust, and the device connection.
2. The stock Omarchy Bluetooth panel displays BlueZ through Quickshell.
3. PipeWire owns the selected audio profile and default output.
4. `librepods.service` owns the Omapods battery and control connection.

A green layer does not prove that the next layer is healthy. Check them in that
order instead of treating the Omapods panel as the Bluetooth source of truth.

## Adapter power and a stale bar widget

On the tested Omarchy `4.0.0-1` installation, the bar said Bluetooth was off
after the USB adapter had been disabled, although the adapter was present,
unblocked, powered, and scanning. Use the backend as the live check:

```bash
omarchy bluetooth power is-on
a=$?; echo "power check: $a"
rfkill list bluetooth
bluetoothctl show
systemctl is-active bluetooth.service
lsusb | grep -i bluetooth
```

`omarchy bluetooth power is-on` returns zero when Omarchy sees any powered
controller. If it succeeds and `bluetoothctl show` reports `Powered: yes`,
treat an off bar icon as stale Quickshell state and reload only the shell:

```bash
omarchy restart shell
```

The recurring Quickshell warning `Failed to stop discovery ... No discovery
started` did not indicate a dead adapter on this host. Recheck `rfkill` and
`bluetoothctl show` before changing hardware or restarting BlueZ.

## Pairing mode versus a BLE advertisement

AirPods can publish their name and Apple manufacturer data over BLE while they
are not pairable as classic Bluetooth headphones. That state made the Omarchy
panel remain on **Pairing** until its 20-second pending timer expired. The
installed `omarchy-bluetooth-device` helper also tolerates failed `pair`,
`trust`, and `connect` calls, so its exit status did not expose the failure.
Inspect its installed source after an Omarchy update before relying on this
quirk:

```bash
readlink -f "$(command -v omarchy-bluetooth-device)"
```

For AirPods Pro, put both pods in the case, close it for 30 seconds, open it,
and hold the rear setup button until the light continuously flashes white. If
that fails, continue holding for about 15 seconds until the light flashes amber
and then white. For AirPods Max, hold the noise-control button for about five
seconds until the light flashes white. Keep nearby Apple devices from taking
the connection during recovery.

Confirm the classic audio advertisement before pairing:

```bash
bluetoothctl --timeout 20 scan bredr
bluetoothctl devices | grep -i airpods
bluetoothctl info <MAC>
```

A pairable record reports `Class`, `Icon: audio-headphones`, and later the
`Audio Sink` UUID. A BLE-only record may show the name, RSSI, and
`ManufacturerData` but no headphone class; pairing that record only times out.
Once the headphone record is present, bypass the panel so BlueZ prints the real
result:

```bash
bluetoothctl pair <MAC>
bluetoothctl trust <MAC>
bluetoothctl connect <MAC>
bluetoothctl info <MAC>
```

A complete result has `Paired: yes`, `Bonded: yes`, `Trusted: yes`, and
`Connected: yes`. BlueZ may rename the Pro to `Edmund’s AirPods Pro - Find My`
after service discovery; Omapods normalizes it back to `Edmund’s AirPods Pro`,
so those names are the same hardware. The known meshify devices identify as:

| Device | Model number | Omapods model |
| --- | --- | --- |
| Edmund's AirPods Pro | `A3063` | AirPods Pro 3 |
| Edmund's AirPods Max | `A3184` | AirPods Max (USB-C) |

Discover Bluetooth addresses live instead of caching them here. Never commit
the pairing keys under `~/.config/AirPodsTrayApp`; re-pairing remains the
recovery boundary.

## Audio and Omapods after pairing or switching models

Pairing does not select the output, and the Omapods plugin deliberately does not
own volume or PipeWire routing. Select the AirPods in the stock Audio panel and
verify the result with:

```bash
wpctl status
```

The desired playback profile is `a2dp-sink-sbc_xq`. Keep the Antlion USB
microphone as the default input so selecting an AirPods microphone does not
replace high-quality A2DP playback with a headset profile.

When switching between the Pro and Max, BlueZ and PipeWire can be connected
while Omapods still shows the previous model or `connected: false`. Restart only
the control daemon, then inspect its published state:

```bash
systemctl --user restart librepods.service
status="${XDG_STATE_HOME:-$HOME/.local/state}/librepods/status.json"
jq '{connected, device_name, model_name, model_number, headset, left, right, case}' "$status"
systemctl --user is-active librepods.service
```

The Max publishes one `headset` battery and no case row. The Pro publishes
`left`, `right`, and `case`. The daemon's `Missing CAP_NET_ADMIN permission`
warning did not prevent either public-address device from connecting. A
successful daemon attachment also reselects the best available A2DP profile;
use `wpctl status` to verify routing separately.
