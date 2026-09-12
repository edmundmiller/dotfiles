---
purpose: Enable the DJI Mic Mini mobile-receiver link button as Raycast dictation start/end.
applies_to: Darwin hosts with the USB mobile receiver and Raycast dictation.
entrypoint: modules.desktop.apps.djiMicMiniRaycastDictation.enable
verification: hey check --worktree; then a live receiver button press starts/stops Raycast dictation.
update_when: The receiver HID IDs, Raycast chord, or remapper (Karabiner vs hidutil/Kanata) change.
---

# DJI Mic Mini → Raycast dictation

Pressing the transmitter link button makes the **mobile USB receiver** emit HID
Consumer Control `0x0C/0xE9` (volume increment). Remap that usage **only** from
the DJI receiver so keyboard volume keys stay untouched. The physical button
then toggles Raycast dictation.

## Hardware assumption

- DJI Mic Mini (or Mini 2) **mobile receiver** plugged in over USB-C
- Receiver USB IDs: vendor `11427` (`0x2CA3`), product `16401` (`0x4011`)
- Bluetooth-only mode exposes audio, not the button HID event

This is the same device already used by
`modules.desktop.apps.djiMicMiniReceiverMute`. The two features share the
button and are mutually exclusive.

## How to enable

1. On the Darwin host (MacTraitor-Pro already does this):

   ```nix
   modules.desktop.apps.raycast.enable = true;
   modules.desktop.apps.djiMicMiniRaycastDictation.enable = true;
   modules.desktop.apps.djiMicMiniReceiverMute.enable = false;
   ```

2. Rebuild with authorized `hey re`. The module only installs
   `~/.config/karabiner/assets/complex_modifications/dji-mic-raycast-dictation.json`.
3. In Karabiner-Elements → Complex Modifications, enable **DJI Mic Mini
   receiver → Raycast dictation** and disable the receiver-mute rule if it is
   still on.
4. In Raycast, bind **Dictation** to **Ctrl+Option+Command+Space**. That
   binding lives in Raycast's encrypted SQLite and is not Nix-managed.

Karabiner-Elements itself is not installed by this module (same pattern as the
mute asset). Grant it Input Monitoring and Accessibility if macOS prompts.

## Why Karabiner instead of Bedesqui's Kanata helper

Igor Bedesqui's working stack in [bdsqqq/dots](https://github.com/bdsqqq/dots):

| Commit | What it established |
| --- | --- |
| [`defaf70`](https://github.com/bdsqqq/dots/commit/defaf703436b4f17170a489c9bb4dc87583f3c9a) | Persist a receiver-only hidutil remap |
| [`0a3a23f`](https://github.com/bdsqqq/dots/commit/0a3a23faf603e3e95c17aadd49ead5129f4af386) | Translate the event toward a Raycast chord |
| [`6ea0e96`](https://github.com/bdsqqq/dots/commit/6ea0e9695e9f3d2d445f3e68e30f7008da1793d7) | Route the chord through virtual HID (`C-A-M-spc`) because event-tap rewrites and `CGEventPost` arrive too late for Raycast |
| [`b3a3190`](https://github.com/bdsqqq/dots/commit/b3a319068bcd4230f5f0ae543bb2a38c7ebf6e73) | Hold the chord 120 ms; Kanata's zero-duration Tap was too short |
| [`273ced1`](https://github.com/bdsqqq/dots/commit/273ced171d9263ed537eb89f172aa60feade423c) | Sign the helper to a stable path so Accessibility TCC survives rebuilds |

Public write-up: [the button works](https://x.com/bedesqui/status/2098541184272544225),
[commits as source of truth](https://x.com/bedesqui/status/2098781296113697105).

This repo already owns that receiver event in Karabiner and already manages
Raycast prefs. Porting Kanata, its VirtualHID LaunchDaemon, an unauthenticated
TCP control port, and a personal Apple Development signing identity would add a
second keyboard stack. Karabiner's VirtualHIDDevice emits the same
`C-A-M-spc` chord for 120 ms, scoped to vendor/product/consumer.

## Blocked / manual pieces

- **Raycast dictation hotkey** — encrypted SQLite; set `⌃⌥⌘Space` once
- **Kanata + signed `dji-mic-hid-remap`** — not ported; no signing identity in
  this flake, and Kanata would fight the existing Karabiner path
- **Host activation** — configuration only; `hey re` still needs authorization
- **Accessibility** — required for Karabiner (already). The Bedesqui helper's
  extra Accessibility grant is unnecessary on this path

## How to verify

1. Plug in the mobile receiver. `system_profiler SPUSBDataType` should show DJI
   vendor `0x2ca3` / product `0x4011`.
2. Confirm Karabiner lists the receiver-scoped rule and that mute is off.
3. Confirm Raycast Dictation is `⌃⌥⌘Space`.
4. Press the transmitter link button once: Raycast dictation starts. Press
   again: it ends. Laptop volume keys must still change volume.
5. `hey check --worktree` covers the rule JSON and MacTraitor-Pro wiring.
   Live button behavior needs the receiver on a Mac.
