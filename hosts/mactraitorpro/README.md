---
purpose: Document human-facing setup and recovery procedures for MacTraitor-Pro.
applies_to: Physical setup and troubleshooting for the personal Mac.
entrypoint: Use the matching troubleshooting section below.
verification: Confirm the affected hardware works in the documented topology.
update_when: Host hardware, cabling, or a verified recovery procedure changes.
---

# MacTraitor-Pro

Human-facing setup and troubleshooting for the personal Mac.

## CalDigit TS5 dual displays on macOS 27

### Stable topology

- Connect the TS5 host cable to the Mac's bottom-left USB-C port nearest the trackpad.
- Connect both the ASUS and LG display cables to rear, lightning-marked TS5 downstream ports.

### Symptom

When the ASUS initializes first, it displays normally while the LG reports hot-plug detection (HPD) but does not establish a video link.

### Isolation ladder

1. Confirm the blank monitor has power and explicitly select its USB-C input.
2. Bypass the TS5 with a known-good, video-rated USB-C cable directly from that monitor to the Mac.
3. Keep the monitor and cable fixed while testing another Mac USB-C port; restore the TS5 to bottom-left port 2 afterward.
4. Reconnect one display at a time using only rear, lightning-marked TS5 downstream ports.
5. Establish 4K at 60 Hz before testing 120/144 Hz; a high-refresh-only failure points to cable, bandwidth, DSC, or display-mode negotiation.

If the known-good direct path fails across Mac ports, test another source or
display to separate the Mac from the monitor/cable. If direct works but the TS5
path fails, escalate with the captured `displayctl macos status` output to
CalDigit. If only high refresh fails, keep 4K60 as the safe mode while checking
the cable and monitor's DisplayPort/DSC settings.

### Recovery

1. Disconnect the ASUS from the TS5.
2. Wait for the LG to appear in macOS.
3. Reconnect the ASUS.

### Long-term diagnostic guard

When activated, the dotfiles configuration runs `displayctl macos status` at
login and every five minutes. It checks the current DisplayPort transport state
and verifies that the TS5 host cable is on Mac USB-C port 2. A new incident is
logged and produces one notification; an unchanged incident remains quiet.

`packages/displayctl/config.json` is the machine-readable source for the
expected port and notification recovery text. This runbook is the human-facing
source for interpretation and escalation. After activation, verify both with
`displayctl macos status` and
`launchctl print gui/$(id -u)/org.nixos.display-link-guard`.

The guard is intentionally read-only. It does not restart WindowServer, change
display defaults, reboot the Mac, or power-cycle hardware. Use the ordered
physical recovery above when it reports a link-training failure.

Diagnostic state is stored under
`~/Library/Application Support/display-link-guard/`; launchd stdout and stderr
are written to `~/Library/Logs/display-link-guard.log` and
`~/Library/Logs/display-link-guard.error.log`.

### Evidence boundary

Both displays work through the TS5 after that connection order. This points to macOS 27 dual-display initialization ordering on this host; it does not prove an Apple-confirmed OS bug. The successful ordered connection also did not identify a capability fault in the TS5, LG, or USB-C-to-DisplayPort cable.
