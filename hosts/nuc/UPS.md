---
purpose: Operate and recover the NUC's CyberPower UPS monitoring and shutdown path.
applies_to: CyberPower S175UC connected by USB to the NUC and surfaced in Home Assistant.
entrypoint: Check `upsc cyberpower@localhost` and the three NUT services.
verification: Confirm `ups.status` changes from `OL` to `OB DISCHRG` during a brief wall-input test.
update_when: UPS hardware, USB identity, NUT policy, HA integration, or shutdown behavior changes.
---

# NUC UPS

The NUC is the sole controller for the CyberPower S175UC. NUT owns the rear
USB-B management connection and performs a normal NixOS shutdown when the UPS
reports `LOWBATT`. Home Assistant connects to NUT at `127.0.0.1:3493` for
read-only telemetry; it does not decide when to shut down and receives no NUT
command credentials.

The UPS's Ethernet-shaped `IN` and `OUT` jacks are surge-protection
pass-through for a copper network line. They do not provide UPS management or
network connectivity. The USB connection is the management path.

## Configuration

- NixOS source: `hosts/nuc/ups.nix`
- Hardware match: USB `0764:0501`, product `S175UC`
- NUT device: `cyberpower@localhost`, driver `usbhid-ups`
- USB quirk: `pollonly` avoids the S175UC's failing HID interrupt-transfer path
- Startup: wait for udev settlement, then retry USB initialization up to five times
- Network exposure: loopback only; TCP 3493 is not opened in the firewall
- Shutdown policy: NUT primary monitor follows the UPS-reported `LOWBATT` state

NUT delays UPS output cutoff for 60 seconds after the operating-system shutdown
begins and requests a 120-second turn-on delay after utility power returns. The
NUC firmware must remain configured to power on after AC restoration for fully
automatic recovery.

## Normal checks

```bash
ssh nuc 'systemctl --no-pager --full status upsdrv upsd upsmon'
ssh nuc 'upsc cyberpower@localhost'
ssh nuc 'ss -ltnp | grep :3493'
```

Healthy line-power telemetry includes `ups.status: OL`. On battery, expect
`ups.status: OB DISCHRG`; battery percentage and runtime should begin falling.
The NUT socket must listen only on `127.0.0.1:3493`.

## Safe functional test

1. Confirm the NUC and networking equipment use outlets labeled battery backup,
   not surge-only outlets.
2. Start `watch -n 1 upsc cyberpower@localhost` on the NUC.
3. Unplug only the UPS wall input for 10–15 seconds; do not switch off the UPS.
4. Confirm `ups.status` changes to `OB DISCHRG`, then reconnect wall input.
5. Confirm it returns to `OL` and review `journalctl -u upsdrv -u upsd -u upsmon`.

Do not deliberately drain to `LOWBATT`, create `/run/killpower`, or run
`upsdrvctl shutdown` on a live system. Those paths intentionally shut down the
NUC and can cut power to the UPS outputs.

## Home Assistant

The NUT config entry is persistent HA state, not Nix-generated YAML. Configure
one NUT integration with host `127.0.0.1`, port `3493`, and no username or
password. After a Nix rebuild, verify the entry and its UPS entities through the
HA API or UI; never edit `/var/lib/hass/.storage` directly.

## Recovery

If `upsc` reports a connection error, check the USB ID with `lsusb -d 0764:0501`
and inspect the three NUT units in driver-to-monitor order. After reconnecting
USB, restart `upsdrv`, then `upsd`, then `upsmon`. If the driver sees the UPS but
telemetry is stale, inspect `journalctl -b -u upsdrv -u upsd -u upsmon` before
changing configuration.
