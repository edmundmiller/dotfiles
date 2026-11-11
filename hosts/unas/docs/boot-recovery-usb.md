---
purpose: Boot UNAS from the Lexar rescue USB and choose a headless recovery method.
applies_to: UNAS firmware boot selection and remote access to the live rescue system.
entrypoint: Verify current media contents and a bootable rescue image before selecting USB boot.
verification: Confirm the rescue hostname over SSH; firmware shortcuts still need confirmation on UNAS.
update_when: The motherboard, firmware boot sequence, or rescue image changes.
---

# Boot UNAS from the Lexar rescue USB

## Media status at BIOS acceptance, November 10, 2026

At BIOS acceptance, the Lexar contained the FAT32 `UNAS_BIOS` partition and the
BIOS 2601 CAP, not a bootable rescue system. Its original full-device rescue image and checksum
receipts remain preserved on NUC-local storage. Do not follow the boot steps
below with BIOS-only media. Recheck the stick's current contents before use.
Restoring that image or preparing a
different rescue stick requires exact-device approval and verification; it was
not part of the accepted BIOS update. Preserve the saved image unchanged.

See the [accepted firmware record](../README.md#accepted-firmware-update-november-10-2026).
The boot instructions below apply only to verified bootable rescue media.

## Rescue boot prerequisites

The live recovery system identifies an ASUS ROG STRIX H470-I GAMING motherboard.
It successfully booted the Lexar in UEFI mode with Secure Boot disabled. The
installed SSD has a separate Linux Boot Manager entry. Reinspect firmware
entries before selecting a one-time target; their numbers can change.
The keyboard sequence below follows the
[ASUS USB boot instructions](https://www.asus.com/support/faq/1013017).
Do not use a guessed sequence of arrow keys without seeing the boot menu.

## Select the USB at startup

1. Plug in the Lexar USB stick and connect Ethernet before powering on.
2. Power on and repeatedly tap **Delete** to enter BIOS.
3. Press **F8** to open the boot menu.
4. Select **UEFI: Lexar USB Flash Drive**, or the equivalent Lexar UEFI entry,
   and press **Enter**. Prefer UEFI if both UEFI and legacy entries appear.

Secure Boot must be disabled for this image. If the USB is missing from the
menu, check the connection and firmware USB boot settings against the board's
manual. Do not change storage-controller modes or format any disks.

The rescue menu selects its default entry after five seconds. Allow a couple
of minutes for networking, then connect from a machine with an authorized key:

```bash
ssh root@unas-rescue.local
```

Confirm that `hostname` reports `unas-rescue`. If mDNS does not resolve the
name, look for `unas-rescue` in the router's DHCP leases and connect to that
address. The rescue system generates fresh SSH host keys each boot; verify a
changed fingerprint at the console rather than disabling host-key checking.

This is a live rescue environment with Determinate Nix, SSH, and ZFS tools.
It does not automatically install NixOS, format disks, or import NAS pools.
Inspect the actual disks over SSH before choosing a repair. The configured
`zroot` pool contains home directories as well as the OS, so wiping the OS
disk is not a data-preserving reinstall.

See the [image build instructions](../README.md#headless-recovery-usb) and
`/etc/unas-recovery.txt` on the running USB for further recovery guidance.

## Choose a headless boot method

You can first try powering on with the Lexar inserted and no monitor attached.
It will boot automatically if the firmware already prioritizes that USB.
Without knowing the boot order, this cannot be guaranteed.

| Method                                   | Requirements and use                                                                                                                                                                               |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Monitor and keyboard                     | Simplest way to select the USB for this recovery. Use the one-time boot menu without changing the permanent boot order.                                                                            |
| UEFI BootNext over SSH                   | Requires a running, reachable installed OS booted in UEFI mode. Inspect entries with `sudo efibootmgr -v`, then select a confirmed USB entry for the next boot only. Do not guess an entry number. |
| IP KVM with virtual media, such as PiKVM | Provides remote video, keyboard input, and installer media even when the OS is broken. Requires compatible video and USB connections; remote power control may need additional wiring.             |
| Built-in IPMI/BMC console                | Provides similar out-of-band access on supported server boards. UNAS support has not been established.                                                                                             |

Use a monitor and keyboard for the current recovery if automatic USB boot
does not work. For recurring headless recovery on a consumer motherboard,
an IP KVM with virtual media avoids needing physical console access each time.

The rescue image has passed UEFI and legacy USB boot tests in virtual machines,
including SSH login and data-preservation checks. Those tests do not confirm
UNAS's physical firmware shortcuts or boot order.
