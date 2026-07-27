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

### Recovery

1. Disconnect the ASUS from the TS5.
2. Wait for the LG to appear in macOS.
3. Reconnect the ASUS.

### Evidence boundary

Both displays work through the TS5 after that connection order. This points to macOS 27 dual-display initialization ordering on this host; it does not prove an Apple-confirmed OS bug. The successful ordered connection also did not identify a capability fault in the TS5, LG, or USB-C-to-DisplayPort cable.
