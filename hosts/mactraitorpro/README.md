---
purpose: Document human-facing setup and recovery procedures for MacTraitor-Pro.
applies_to: Physical setup and troubleshooting for the personal Mac.
entrypoint: Use the matching troubleshooting section below.
verification: Confirm the affected hardware works in the documented topology.
update_when: Host hardware, cabling, or a verified recovery procedure changes.
---

# MacTraitor-Pro

Human-facing setup and troubleshooting for the personal Mac.

## Workload placement

- [Amp Orb, Mac, NUC, and Meshify routing](workload-placement.md) — keeps
  repository-contained agent work remote while reserving each physical host
  for its data, platform, hardware, and final acceptance boundaries.

## Storage

- [Disk-space ledger and recovery](storage.md) — explains the APFS total,
  nested home/iCloud/Codex usage, likely regrowth, and supported reclaim paths.

## Voxtype setup and upgrades

The Homebrew cask installs `/opt/homebrew/bin/voxtype`, **not**
`/Applications/Voxtype.app`. The app bundle owns the recording daemon,
permissions, and menu bar. Nix manages its Login Item and the separate waveform
overlay, not a second menu-bar process.

After the first authorized `hey re` installs the cask, run this as `emiller`:

```bash
/opt/homebrew/bin/voxtype setup app-bundle
```

This copies the CLI into the app, signs it, adds a Login Item, and opens it.
Grant Voxtype Accessibility, Input Monitoring, and Microphone access in System
Settings. Confirm Voxtype appears under General > Login Items. The upstream
`setup app-bundle --status` check can report a missing Login Item when System
Events automation is unavailable, so verify it in Settings too.

For an upgrade, finish or cancel any recording and quit Voxtype from its menu
bar. Install the authorized cask update through the repository's guarded
Homebrew workflow, then rerun `setup app-bundle` above and re-grant permissions
if prompted. Do not run the installer on every rebuild: upstream resets
Accessibility and Input Monitoring grants whenever it copies from the CLI,
even if the version has not changed. Reopening an already running app does not
replace its process, which is why quitting before the update matters.

Verify the bundle and cask versions match:

```bash
/opt/homebrew/bin/voxtype --version
/Applications/Voxtype.app/Contents/MacOS/voxtype-bin --version
```

`hey re` warns if the bundle is missing, cannot report its version, or differs
from the installed CLI. It does not recreate the bundle or reset permissions.
After setup or an upgrade, confirm one Voxtype menu-bar icon and test hold-Fn
dictation in a scratch text field. On cancellation, the overlay should retract
without inserting text. The overlay also treats streaming capture as recording.

## CalDigit TS5 dual displays on macOS 27

### Preferred display arrangement

Keep this layout when troubleshooting or restoring displays. The ASUS is the main display, with the portrait LG immediately to its right and their top edges aligned. The MacBook sits below the LG, with their right edges aligned. Use an extended desktop, not mirroring.

The user confirmed this arrangement on 2026-10-24. These are the matching live macOS logical coordinates, not physical pixel counts:

| Display                            | Origin (x, y) | Logical size | Rotation |
| ---------------------------------- | ------------- | ------------ | -------- |
| ASUS XG32UCWMG, main               | (0, 0)        | 1920 × 1080  | 0°       |
| LG Ultra HD                        | (1920, 0)     | 1080 × 1920  | 270°     |
| Built-in Liquid Retina XDR Display | (1648, 1920)  | 1352 × 878   | 0°       |

If scaling changes, preserve the relative placement and edge alignment rather than reusing these coordinates unchanged. This records the desired layout; it does not install automatic layout restoration.

### Current status

The one-cable, dual-display setup remains unresolved. Turning off DSC restored
the ASUS picture at 4K 60 Hz, but the LG later disappeared from macOS. Reconnecting
the LG first briefly restored both displays, not sustained operation.

These findings come from the [display troubleshooting thread](https://ampcode.com/threads/T-01a1701f-1a3a-7775-aa3f-c2a8c2ca99b1).

### Hardware and cabling

| Component   | Confirmed details                                                                  |
| ----------- | ---------------------------------------------------------------------------------- |
| MacBook Pro | Mac15,6, Apple M3 Pro, 36 GB RAM; macOS 27.0.1, build 26A434 during testing        |
| Dock        | CalDigit TS5, not TS5 Plus; USB4 host connection negotiated at 40 Gb/s             |
| ASUS        | ROG Strix OLED XG32UCWMG; observed at 3840 × 2160 at 144 Hz and 60 Hz              |
| LG          | macOS identifies it as LG Ultra HD; 4K 60 Hz, portrait; exact retail model unknown |

The M3 Pro supports two external displays. This is not the base-M3 single-external-display
limit, and the TS5's Thunderbolt 5 rating does not make this a Thunderbolt 5-speed
host connection.

- Connect the TS5 host cable to the Mac's bottom-left USB-C port nearest the trackpad.
- Connect both the ASUS and LG display cables to rear, lightning-marked TS5 downstream ports.
- Ordinary TS5 USB-C data/power ports do not provide video.
- The ASUS uses its USB-C display input. Earlier recovery notes mention a
  USB-C-to-DisplayPort cable. Testing also detected a Cable Matters USB-C Video
  Cable, but did not establish which monitor used it.

### Preferred extended-desktop arrangement

Use an extended desktop, not mirroring. The ASUS is the main display. Put the
portrait LG immediately to its right with their top edges aligned. Put the
MacBook below the LG with their right edges aligned.

| Display    | Logical origin | Logical size  | Rotation |
| ---------- | -------------- | ------------- | -------- |
| ASUS, main | `(0, 0)`       | `1920 × 1080` | 0°       |
| LG         | `(1920, 0)`    | `1080 × 1920` | 270°     |
| MacBook    | `(1648, 1920)` | `1352 × 878`  | 0°       |

These are logical coordinates, not panel pixels. Preserve the relative placement
if scaling changes. Automatic layout restoration is not implemented.

### Tested behavior

| Test                                  | Result                                                                                                                                                     |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Connect LG first, then ASUS           | Previously recovered both displays. In the latest test with DSC off, both were detected at 4K 60 Hz for about 35 seconds; LG later disappeared from macOS. |
| Swap TS5 display ports                | Both became listed in macOS, but only LG had a picture. The swap also changed connection order, so it did not isolate a faulty port.                       |
| Lower ASUS from 4K 144 Hz to 60 Hz    | Session-only diagnostic. Colored vertical bands/noise persisted, including after reconnecting to the same dock port.                                       |
| Connect ASUS directly to Mac          | User confirmed this works. The direct-connection refresh rate was not established. Do not repeat this as an untried isolation test.                        |
| Update TS5 firmware                   | Verified update from 64.1 to 71.1, with port micro firmware 1.18.0, using CalDigit macOS updater 2.12. ASUS corruption returned after a port change.       |
| ASUS System Setup → DSC Support → Off | Restored the ASUS picture at 4K 60 Hz. It did not restore sustained dual-display operation.                                                                |

### Update TS5 Thunderbolt firmware on macOS

This procedure successfully updated this TS5 on October 24, 2026, from firmware
64.1 to 71.1 and port micro firmware 1.11.0 to 1.18.0. It uses CalDigit
Thunderbolt Firmware Updater 2.12 and requires macOS 14.6 or later and local
administrator authorization. This is not the separate USB Power Delivery updater.
Check [CalDigit's procedure](https://www.caldigit.com/ts5-plus-and-element-5-hub-macos-firmware-update-procedures/)
for newer releases before repeating it. Agents need explicit authorization before
updating hardware firmware.

1. Use the MacBook's built-in screen and keyboard, keep the Mac on AC power, and
   eject any dock-connected storage before disconnecting it. Remove dock
   peripherals, including external monitors, and disconnect other CalDigit
   devices. Update only one CalDigit device at a time.
2. Allow the TS5 if macOS asks **Allow accessory to connect?** In **System Settings
   → Privacy & Security → Accessories**, note the existing setting and select
   **Ask for new accessories**.
3. Download [CalDigit Thunderbolt Firmware Updater 2.12](https://downloads.caldigit.com/TS5Plus/CalDigit_Thunderbolt_Firmware_Updater_v2.12.pkg.zip)
   and unzip it. The `TS5Plus` download directory also serves the TS5 package.
   Before installation, run these checks from the directory containing the package:

   ```sh
   pkgutil --check-signature CalDigit_Thunderbolt_Firmware_Updater_v2.12.pkg
   spctl --assess --type install --verbose=2 CalDigit_Thunderbolt_Firmware_Updater_v2.12.pkg
   ```

   Both checks passed in the recorded update. Expect **Developer ID Installer:
   CalDigit, Inc (8R7PS6VYW7)** and **accepted**, with **Notarized Developer ID**.
   Stop if verification fails; do not bypass macOS security checks.

4. Disconnect the TS5's host cable from the Mac, leaving the dock connected to
   wall power. Open the `.pkg` in Installer and complete installation. Enter the
   administrator password only in the macOS prompt.
5. Reconnect the TS5 to the Mac. In the **Accessory Update Available** notification,
   select **Options → Update**. Installing the package alone does not flash the dock.
6. When macOS asks you to replug the dock, disconnect its host cable for **5 seconds**.
   Dismiss the prompt while unplugged, then reconnect.
7. Leave the Mac awake and the dock connected to both the Mac and wall power for
   **8–10 minutes**. There is no progress bar. **Do not disconnect either cable
   during flashing.** The dock restarts automatically; click **Allow** if prompted.
8. Verify in **System Information → Thunderbolt / USB4 → TS5**, or run:

   ```sh
   system_profiler SPThunderboltDataType
   ```

   Locate the TS5 entry. The completed update showed `Firmware Version: 71.1` and
   `Micro Firmware Version: 1.18.0`. During this run, the old version remained
   visible for several minutes before changing. An installer receipt or an
   elapsed timer alone does not prove the flash completed.

9. After verification, restore the previous Accessories setting and reconnect
   peripherals. CalDigit also provides an optional
   [updater uninstaller](https://downloads.caldigit.com/Thunderbolt-Firmware-Updater-Uninstaller.dmg.zip).
   Uninstallation was not tested in this run.

If the update notification is missing before flashing starts, check Notification
Center and turn off Focus modes. CalDigit recommends disconnecting external
displays and reconnecting the dock, then restarting the Mac if the prompt still
does not appear. These are vendor fallback steps, not recoveries needed in the
recorded update. Do not restart or replug to troubleshoot an active flash.

The firmware update succeeded, but did not fix the dual-display failure. Verify
monitor behavior separately using the recovery checks below.

### Workaround and recovery attempt

Keep ASUS **System Setup → DSC Support → Off** while investigating through the
TS5. If the LG is missing, try the previously successful connection order:

1. Disconnect the ASUS from the TS5.
2. Wait for the LG to appear in macOS and confirm it has a picture.
3. Reconnect the ASUS.
4. Check for clean, updating pictures on both physical monitors and sustained
   operation. macOS listing both displays as online is insufficient.

The practical fallback is to connect ASUS directly to the Mac and leave LG on
the TS5. The direct-ASUS test passed, but long-term stability of this complete
two-cable arrangement has not been demonstrated or adopted as the final setup.

### Untested diagnostics and trade-offs

The proposed next test was ASUS **System Setup → DisplayPort Stream →
DisplayPort 1.2**, retaining DSC off. No result was recorded. Treat it as a
temporary diagnostic, not the desired performance setting.

Refresh rate controls how often pictures are sent. DSC compresses the video
stream. DisplayPort 1.2 versus 1.4 changes the advertised link capabilities.
Lowering refresh rate alone did not resolve the ASUS corruption.

The ASUS connection was observed using two DisplayPort lanes at HBR3,
8.1 Gb/s per lane. Switching to DP 1.2 may limit this two-lane connection to
4K 30 Hz; that is a predicted trade-off, not an observed result. Four-lane
DP 1.2 can support 4K 60 Hz.

The ASUS manual also offers **Type-C Bandwidth → USB 2.0 / USB 3.2**. It lists
USB 3.2 operation up to 3840 × 2160 at 144 Hz with DSC enabled. Changing this
setting has not been tested.

### Evidence boundary

The results implicate the dock-mediated display connection or negotiation, but
do not identify a specific hardware defect or an Apple-confirmed macOS bug.
Turning off DSC also renegotiates the link, so it does not prove compression
alone is the cause. Neither the firmware update nor the port swap was a verified
dual-display fix.

#### Earlier local observations, 2026-10-24

Both displays initially worked through the TS5 after that connection order. This suggested macOS 27 dual-display initialization ordering on this host; it did not prove an Apple-confirmed OS bug. The successful ordered connection also did not identify a capability fault in the TS5, LG, or USB-C-to-DisplayPort cable. Later failures are recorded above.

During a recurrence on 2026-10-24, swapping the displays' downstream ports made both appear online in macOS, but the ASUS did not show a usable picture. A session-only change from 4K 144 Hz to 4K 60 Hz left the ASUS showing colored vertical bands and noise while the LG displayed normally. Neither the port swap nor the refresh-rate change was a verified recovery. Require a usable picture on both physical monitors; macOS reporting both online is insufficient.

Reconnecting the ASUS to the same dock port at 60 Hz also failed to clear the corruption. The user confirmed that direct ASUS-to-Mac connection already works; do not repeat that isolation test without a new reason. This implicates the dock-mediated connection, not necessarily defective dock hardware.

The dock initially reported Thunderbolt firmware 64.1. With explicit user authorization, it was updated using CalDigit's signed, notarized macOS updater 2.12. At 19:42 America/Chicago on 2026-10-24, two successive System Information checks confirmed firmware 71.1 and port micro firmware 1.18.0. [CalDigit's firmware instructions](https://www.caldigit.com/ts5-plus-and-element-5-hub-macos-firmware-update-procedures/) describe 71.1 as improving monitor and USB stability. The firmware update is verified; resolution of the display corruption still requires a clean picture on both monitors through the dock. Future updates require explicit authorization, physical reconnects, and up to 8–10 minutes of uninterrupted dock power and host connection while flashing.

Corruption recurred after a port change on firmware 71.1, so the update alone did not resolve it. Turning off **System Setup → DSC Support** in the ASUS's physical menu then restored a usable ASUS picture, confirmed by the user, with macOS reporting 4K 60 Hz. Keep DSC off while investigating the remaining LG detection failure. This implicates compression or the link renegotiation caused by the setting change; it does not establish a specific component's defect. Dual-display recovery with DSC off remains unverified.

### References

- [CalDigit TS5 connection guidance](https://www.caldigit.com/thunderbolt-5-dock-ts5/)
- [CalDigit macOS firmware update procedures](https://www.caldigit.com/ts5-plus-and-element-5-hub-macos-firmware-update-procedures/)
- [ASUS manual, page 33, Type-C bandwidth](https://mans.io/files/viewer/3457953/33)
- [ASUS manual, page 34, DisplayPort Stream and DSC](https://mans.io/files/viewer/3457953/34)
