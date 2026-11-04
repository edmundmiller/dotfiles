---
purpose: Update Meshify's ASUS PRIME X570-P BIOS using ASUS EZ Flash 3.
applies_to: Planned motherboard firmware updates performed locally at Meshify.
entrypoint: Confirm the board model, recovery credentials, and ASUS release notes before preparing a USB stick.
verification: Confirm the installed BIOS version, Linux boot, disk unlock, and required firmware settings.
update_when: The motherboard changes, ASUS changes its update procedure, or a BIOS update is verified.
---

# Update Meshify's BIOS

Use ASUS EZ Flash 3 inside the firmware setup. Windows is not required. Prepare
the download remotely if useful, but perform the update while physically at
Meshify. Documentation or download preparation does not authorize flashing,
rebooting, formatting a drive, or clearing the TPM.

## Confirm the hardware and target

Hardware observed on October 25, 2026:

| Component      | Observed value                        |
| -------------- | ------------------------------------- |
| Motherboard    | ASUS PRIME X570-P, not PRIME X570-PRO |
| CPU            | AMD Ryzen 7 3800X                     |
| Installed BIOS | 1404, dated November 8, 2019          |
| Boot mode      | UEFI                                  |
| GPU            | NVIDIA GeForce RTX 2070 SUPER         |

Read the current version before each update; these observations are not a
record of a completed flash:

```bash
hostname
cat /sys/class/dmi/id/board_name
cat /sys/class/dmi/id/bios_version
cat /sys/class/dmi/id/bios_date
```

Download only from the [ASUS PRIME X570-P BIOS page](https://www.asus.com/us/motherboards-components/motherboards/prime/prime-x570-p/helpdesk_bios?model2Name=PRIME-X570-P).
On October 25, 2026, its latest non-beta release was **5044**, dated January 27, 2026. Recheck the page when doing the update. Read the selected release's
warnings and any prerequisites; do not assume every future release allows a
direct upgrade or downgrade.

## Prepare before rebooting

- Back up important files and save open work.
- Have a working disk-encryption passphrase or recovery key available outside
  the computer. Do not rely solely on TPM-based automatic unlock. ASUS's newer
  releases include fTPM updates and warn about encryption recovery. If dual
  booting Windows, save its BitLocker recovery key and follow its firmware-update
  precautions too. Do not clear the TPM or post recovery credentials in a chat.
- Use reliable power, preferably a UPS. Avoid flashing during a power outage risk.
- Use a USB stick with a single FAT32 partition. Back up its contents first if
  formatting is needed; formatting erases data. Do not guess a Linux device path
  or format an unidentified disk.
- Download the BIOS ZIP for **PRIME X570-P**, extract it, and copy the `.CAP`
  file to the USB stick's top-level directory. Compare the downloaded archive's
  SHA-256 with ASUS's published checksum when provided. Safely eject the stick.
- Have a keyboard and monitor connected directly to Meshify.

## Flash with ASUS EZ Flash 3

1. Insert the USB stick, restart Meshify, and repeatedly press **Delete** at
   the ASUS logo to enter firmware setup.
2. Photograph the current boot order, Secure Boot and CSM settings, storage
   controller mode, DOCP memory settings, fan curves, and any other custom
   settings. The update may reset them.
3. Press **F7** for Advanced Mode, then open **Tool → ASUS EZ Flash 3 Utility**.
4. Select the USB stick and its `.CAP` file. Check the motherboard and target
   version shown by EZ Flash before confirming. If it rejects the image, stop
   and recheck the model, extraction, and release prerequisites. Do not force it.
5. Confirm the update. **Do not power off, reset, or remove the USB stick while
   flashing.** Follow the utility's completion prompt and allow its restarts.
6. Allow extra time for the first boot and memory training. Re-enter setup to
   confirm the version and review settings that changed. Restore necessary
   settings deliberately rather than importing an old BIOS profile wholesale.

The [ASUS EZ Flash 3 guide](https://www.asus.com/support/faq/1012815/) provides
illustrated instructions. If the machine cannot boot afterward, inspect the
firmware boot order, storage mode, and Secure Boot settings before changing the
Linux installation. Use ASUS's model-specific recovery guidance if firmware
setup itself is inaccessible; do not assume a downgrade is supported.

## Verify before making other changes

1. Confirm Linux boots and encrypted disks unlock.
2. Re-run the version commands above and compare with the selected release.
3. Check keyboard input, display output, network connectivity, and fan behavior.
4. Review boot order, storage mode, Secure Boot, and desired memory settings.
5. Record the installed version, date, and verification results here after an
   actual successful update. No BIOS flash was performed while writing this guide.

## ReBAR requires a different GPU too

ASUS added a ReSize BAR shortcut in BIOS 3001 and Ryzen 3000 Smart Access Memory
support in 3602. A newer BIOS prepares this motherboard for a compatible GPU,
but **does not add supported ReBAR to the RTX 2070 SUPER** or enlarge its current
256 MiB BAR1 window.

With a supported replacement GPU, follow [ASUS's ReBAR instructions](https://www.asus.com/support/faq/1046107/).
Check the required Above 4G Decoding, Re-Size BAR, and UEFI/CSM settings, then
verify the actual mapping size in Linux with `nvidia-smi -q -d MEMORY`. Treat
enabling ReBAR as a separate change after the BIOS update boots successfully.
