<!-- Human docs for UNAS host: deploy, identity policy, and storage layout. -->

# UNAS

NixOS NAS host (`hosts/unas/`).

## Identity (public-safe)

- MAC (redacted): `d4:5d:64:**:**:**` (ASUSTek OUI)
- Keep full MAC out of public git.
- If IP drifts, resolve from router DHCP leases using MAC prefix.

## Deploy

From repo root:

```bash
hey unas
```

When the controller has no Nix, transfer the exact source to UNAS and run
`hey unas local` there. It checks the hostname and switches the installed system.
Keep the pre-recovery source snapshot and home checkout unchanged.

SSH helper:

```bash
hey unas-ssh
```

## Rex remote server

`default.nix` enables Rex as `emiller:users`, with an owner-only local socket
and persistent state in `/var/lib/rex`. Its embedded Tailscale node is named
`unas-rex`, separate from the NAS system Tailscale node and Serve settings.
Tailscale ACLs control which tailnet peers can connect. This includes tagged
NUC clients; Rex's owner-only policy would reject them.

After an authorized `hey unas` deployment, enroll Rex once using its Tailscale
login flow on UNAS. Do not put an auth key in Nix. Confirm the address with
`rex server tailscale pair --json` on UNAS. The expected address is
`https://unas-rex.cinnamon-rooster.ts.net`; enrollment must confirm it.

`config/rex/init.lua` declares the `unas` host for both Macs. After an authorized
Mac activation and `rex config reload`, check `rex hosts check unas --json` and
`rex -S unas whoami --json`. Check `rex -S unas client ls --json` separately
for an app connection. On NUC, add the same URL with `rex hosts add unas` and
verify `rex -S unas whoami --json`. Use `REX_RUNTIME_DIR=/run/rex` when managing
the system Rex service over SSH. A new remote terminal should report `emiller`
and `/home/emiller` for `whoami` and `pwd`.

## Key files

- `default.nix` — host imports + enabled modules
- `disko.nix`: disk layout + Btrfs filesystems and subvolumes
- `nas.nix` — NFS exports + firewall
- `modules/time-machine.nix` — Time Machine via netatalk
- `backups.nix`: Btrbk snapshots and replication, Btrfs scrubs, and Restic backups
- `users.nix` — local users/groups
- [Storage benchmark and Btrfs migration plan](storage-benchmark-and-migration.md)
- [Rescue access](docs/recovery-access.md): standalone image build and approved SSH access

## Accepted firmware update, November 10, 2026

Edmund accepted the BIOS upgrade on November 10 in America/Chicago, November 11
UTC. The attended update used ASUS EZ Flash 3, with monitor, keyboard and UPS
power confirmed. This record documents that maintenance, not authorization for
another flash, reboot or deployment.

| Component              | Before                                 | After                                       |
| ---------------------- | -------------------------------------- | ------------------------------------------- |
| Motherboard            | ASUS ROG STRIX H470-I GAMING, Rev 1.xx | Unchanged                                   |
| CPU                    | Intel Core i5-10400                    | Unchanged, 6 cores / 12 logical CPUs online |
| BIOS                   | AMI 0602, April 3, 2020                | 2601, October 29, 2021 build                |
| ME, firmware setup     | 14.0.33.1125                           | 14.1.51.1528                                |
| Memory, firmware setup | 32 GiB at 2666 MHz                     | 32 GiB at 2133 MHz                          |

The image was `ROG-STRIX-H470-I-GAMING-ASUS-2601.CAP`, 33,558,528 bytes, from
the [official ASUS ZIP](https://dlcdnets.asus.com/pub/ASUS/mb/BIOS/ROG-STRIX-H470-I-GAMING-ASUS-2601.ZIP).
The CAP SHA-256 was
`9e4651cdb686bcc50cb87d4a52b0a6f60963292425a7da185b9dfffa75265178`.
Physical Lexar readback matched on November 9. No independent ASUS checksum or
capsule-signature verification was performed; EZ Flash accepted the exact board
and image. BIOS 2601 was the latest non-beta release in the inspected listing;
3005 beta was not selected.

EZ Flash requested an ME-unlock reset followed by repeating the BIOS update.
The attended procedure followed that prompt and reached BIOS 2601. No separate
ME updater ran. This observed sequence does not establish a separate ME-first
requirement for other updates. Postboot ME sysfs returned these three raw lines:

```text
0:14.1.51.1528
0:14.1.51.1528
0:14.0.51.1528
```

The differing third line remains unexplained. It was not normalized to the
firmware setup's displayed version.

### Verification and retained settings

Read-only checks through the existing pinned NUC SSH route at November 10
23:18:57–23:19:40 UTC confirmed:

- Running and booted NixOS both matched accepted closure
  `i8s5dd8q5fizhww8xv9y80pnhamm6fs0-nixos-system-unas-26.11.20260714.18b9261`,
  with current and default boot entry generation 3, kernel 6.18.38.
- Expected system, bulk, preservation, history and child mounts were present.
  All inspected Btrfs filesystems had zero missing devices. All four devices
  had zero write, read, flush, corruption and generation error counters. Recovery history remained
  at `/var/lib/unas-zfs-history`. The `/nix/store` read-only bind was confirmed
  separately at 23:21:11 UTC.
- There were no failed units or queued jobs. NAS sharing, SSH and Tailscale were
  active; NUC TCP connections to ports 22, 2049 and 548 succeeded.
- Postboot Btrbk snapshot completed at 23:18:06 UTC and replication at
  23:18:24 UTC. Restic had not run after reboot; its next trigger was November 11
  06:00 UTC. No new scrub or repair ran as verification.

At November 11 00:08:18 UTC, NUC downloaded an existing 26-byte NAS home file
over SFTP, exit 0. Client and server sizes and SHA-256 matched; the server hash
was stable before and after. The local temporary download was removed. This
tested NVMe-backed home data, not NFS/AFP, HDD-share, Time Machine, restore or
long-term stability. Edmund accepted those limits.

The preflash boot baseline was AHCI, CSM Disabled, Secure Boot OS Type Other OS,
and Linux Boot Manager on NVMe first. The owner reported no change list at F10.
Postboot Secure Boot remained disabled; TPM2 support changed from no to yes.
Preflash VMX and VT-d were disabled. Postboot kernel messages confirmed VMX
disabled by BIOS, with no `vmx` CPU flag or `/dev/kvm`. This is not evidence of
a flash regression. RAM-speed restoration and virtualization enablement remain
separate follow-ups; provider activation and registration remain gated.

At BIOS acceptance, the Lexar held the BIOS CAP, not a bootable rescue installation. Its original
full-device rescue image and checksum receipts remain on NUC-local storage,
unchanged. Recovery boot was not tested during this update. The board supports
CrashFree BIOS 3 with recovery filename `RSH470IG.CAP`, not hardware USB
FlashBack. Recovery is not guaranteed, and NixOS rollback cannot undo firmware.
Use the [board manual](https://dlcdnets.asus.com/pub/ASUS/mb/LGA1200/ROG_STRIX_H470-I_GAMING/E16233_ROG_STRIX_H470-I_GAMING_UM_WEB.pdf)
before any separately authorized recovery or media rewrite.

Evidence: [BIOS maintenance and acceptance](https://ampcode.com/threads/T-01a1c75c-5408-72e8-8e9d-4374ce07c39b),
[firmware guide](https://ampcode.com/artifacts/nas-first-bios-update-guide-and-firmware-assessment-f4dda215-dfab-4e2e-a7b8-bb58bfabd244),
and [postboot and NUC file-read receipts](https://ampcode.com/artifacts/unas-btrfs-assessment-and-migration-gates-956a38ed-e820-4f02-a715-0e288eb10580).
These links require existing access; this repository contains no credentials or
private file contents.

## Storage and recovery

The NVMe uses separate Btrfs subvolumes for root, home, var, Nix, snapshots, and
legacy ZFS history. The two bulk HDDs use Btrfs RAID1 for data and metadata.
The separate preservation disk is outside disko's destructive target set.

Optional bulk mounts can time out without blocking SSH or NVMe boot. The
`unas-share-recovery` timer retries normal NFS and Time Machine starts every
minute, so late storage can recover without restarting healthy shares. Every
attempt still requires the existing filesystem and subvolume identity checks.

Btrbk snapshots root, home, and var independently, then replicates them to bulk
and preservation storage. Documents also replicate to preservation. These
snapshots exclude Nix and do not replace the retained installation closure.

Legacy ZFS history remains native streams at `/var/lib/unas-zfs-history`, with
copies at `/data/legacy-zfs` and on `/preservation`. Reading that history requires
a ZFS-capable recovery environment. A Nix generation rollback cannot undo disk
formatting. See [host provisioning and redeployment](../../docs/install.md#nixos-host-setup-and-redeployment)
before any disk work.

## Notes

- Host may be powered off / stale if unused for long periods.
- If deploy fails with SSH refused, enable sshd from local console first.

## Headless recovery USB

For the firmware key sequence, SSH connection, and remote-console options, see
[Boot UNAS from the Lexar rescue USB](docs/boot-recovery-usb.md).
At BIOS acceptance, the Lexar held the BIOS update file, not the rescue image.
Verify its current contents and bootable rescue media before using those steps.
The older [redeployment guide](docs/redeploy-from-rescue.md) describes ZFS pool
recovery. Do not apply its storage assumptions to the migrated Btrfs layout.

`recovery-image.nix` extends a pinned [Determinate NixOS ISO](https://docs.determinate.systems/guides/nixos-isos/)
independently of the host flake. Determinate Nix and `fh` are installed in the
live environment only. The default build uses the seven canonical SSH login
entries without a separate public-key file. See [Rescue access](docs/recovery-access.md)
for the build command, key restrictions, and storage inspection precautions.
The image keeps the LTS kernel entry because upstream's optional latest-kernel
entry disables ZFS. It does not install, format disks, or import pools on boot.
Any authorized Btrfs inspection mount needs `ro,rescue=nologreplay`; `ro` alone
can replay the tree log. Building an image does not update physical USB media.
