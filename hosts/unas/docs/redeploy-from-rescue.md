---
purpose: Retain historical ZFS recovery steps and route current UNAS redeployment safely.
applies_to: Historical ZFS recovery after confirming the actual storage layout.
entrypoint: Inspect hosts/unas/disko.nix and read the host provisioning guidance first.
verification: Build the host, run scoped checks, and verify storage and services after reboot.
update_when: Pool identities, deployment guards, secrets, or recovery constraints change.
---

# Historical ZFS redeployment from rescue

The current [UNAS disko configuration](../disko.nix) declares Btrfs, not the ZFS
installation recorded below. Do not apply these former pool GUIDs or mount steps
to the migrated NAS. For new host setup or redeployment, follow the
[host provisioning guidance](../../../docs/install.md#nixos-host-setup-and-redeployment).
It defines disko as the layout source of truth and requires separate approval,
device validation, preservation checks, and staged targets for destructive work.
Any necessary imperative cleanup is a documented exception, not a replacement
layout.

Use the [Lexar recovery USB](boot-recovery-usb.md) to restore SSH access, then
inspect storage before importing anything. The recovery image does not import
pools automatically. Deployment requires explicit authorization.

## Pool names are not unique

The November 2026 inspection found these separate pools:

| Pool GUID              | Devices                               | Observed state                                             |
| ---------------------- | ------------------------------------- | ---------------------------------------------------------- |
| `17576335980796613953` | NVMe `20092410240085`, partition 2    | Online `zroot`, including 142 GiB in `emiller`'s home      |
| `5553631198264591155`  | 16 TB disks `2PHTEHKT` and `3HGZMWEN` | Online `datatank` mirror, almost empty                     |
| `3888245209138560581`  | 18 TB disk `3FH06MJT`                 | Older degraded `datatank`, almost empty                    |
| `10347620144501571126` | 6 TB disk `WD-WX21D39DZLK1`           | Older unavailable `datatank`, missing entire mirror groups |

Import by GUID with explicit device paths. Never run `zpool import datatank`
against every disk. The host's udev rules and per-pool `devNodes` setting restrict
automatic `datatank` discovery to the two 16 TB mirror members. The older disks
are excluded, not erased. Missing members do not establish that their data is
disposable or permanently unrecoverable.

`disko.nix` describes the intended layout. **Do not execute its formatting
workflow on this installation.** The OS disk also holds home directories.
Do not run `zpool upgrade` during recovery; keep pool compatibility with the USB.

## Build before selecting a new generation

Inspect imported pools with `readonly=on`, `cachefile=none`, and no automatic
mounts first. Record the old system profile and ESP contents. After approving
the target identities, export the read-only imports and import only the chosen
pools read-write. Take recursive snapshots before changing their contents.

Mount the existing root, Nix store, `/var`, all three home datasets, and the ESP
under a single target root such as `/mnt/unas`. The internal ESP is PARTUUID
`da97d5b7-2689-4895-8934-1f1d3ca8a5ec`; `/boot` is its installed mountpoint.
Mount the data datasets at their declared paths too. On the existing pool,
create only missing datasets declared in `disko.nix`, never recreate the pool.

Preserve `/etc/ssh/ssh_host_*`, the existing users, and service state. Restic's
runtime identity belongs at `/home/emiller/.ssh/id_ed25519`, owned by `emiller`
with mode `0600`. Provision it securely on UNAS; do not copy it into the source
tree or the Nix store. Shared-secret discovery intentionally selects no shared
secrets until UNAS is explicitly added as a recipient.

`/home/emiller` must mount in the initrd so agenix can read this identity during
boot activation. The encrypted Restic target contains an rclone `remote:path`;
the host's Restic wrapper adds `rclone:` in memory. It never initializes or
prunes a repository during recovery.

Transfer the exact source tree, including local changes, into the rescue
environment. Preserve its source revision marker using the existing
`bin/write-nuc-deploy-revision` helper. This marker is also required for UNAS
because the common NixOS configuration records both dotfiles and agents-workspace
revisions. Do not overwrite the old checkout in the home dataset.

Build into the mounted installation's store to avoid filling the USB's RAM root:

```sh
nix build .#nixosConfigurations.unas.config.system.build.toplevel \
  --store /mnt/unas --extra-substituters 'auto?trusted=1' \
  --no-link --print-out-paths --no-write-lock-file --accept-flake-config \
  --max-jobs 2 --cores 2
```

Private inputs need authorized access. An alternative to sending credentials
to the rescue environment is to fetch the locked archives on the workstation,
verify their NAR hashes against `flake.lock`, and copy the resulting source
store paths to the target store. Do not alter lock pins to bypass authentication.

Run `hey check` for the changed paths and inspect the evaluated filesystems,
SSH keys, import rules, and service dependencies. Then run on the rescue host:

```sh
hey unas-recover /mnt/unas /nix/store/BUILD-nixos-system-unas-VERSION
```

Use the actual store path printed by the build. The command refuses the wrong
host, pools, mounts, or ESP. Before any snapshot, backup, profile change, or
installation, it checks the ESP's available bytes against a conservative boot
file budget. Then it snapshots both pools, backs up the ESP boot files, roots
the previous system in a named profile, and installs the built system for the
next boot. The first recovery creates the missing `system-profiles` directory
and `pre-recovery`. Later recoveries keep
that original profile and create `pre-recovery-<UTC timestamp>` for the system
being replaced, using the snapshot timestamp. Each profile retains its current
system through normal generation cleanup and Nix GC, even if installation fails
after creating the profile. These profiles need explicit retirement when their
rollback systems are no longer needed. The command neither formats storage nor
reboots.

Inspect the new profile and boot entry before cleanly unmounting, exporting the
pools, and rebooting. Keep the Lexar USB attached as a fallback. Resolve the
installed system's DHCP address again; it can differ from the live USB address.
If it changes, update the three address references listed in `../AGENTS.md`.

### Keep rollback retention within ESP capacity

The internal ESP is 512 MiB. Each named rollback profile can keep a distinct
kernel and initrd bootable, even when the ordinary system generation limit is
small. Do not add a RAM-root rescue image to this ESP or resize partitions as
part of recovery.

The preflight reads `boot.json` for the new system, the system being replaced,
and the normal and named generations selected by the new configuration's
per-profile limit. It includes specialisations and deduplicates shared boot
payloads. Absolute store symlinks resolve inside the mounted installation,
not against the rescue host's store. Existing ESP payloads need no fresh copy.
The new system's `etc/unas-recovery-boot.json` supplies its evaluated bootloader
binary, mountpoints, extra files, and generation limit.

The budget charges filesystem allocation units, new payloads, both bootloader
copies, extra files, and entry metadata. It also reserves the largest pending
copy for temporary replacement and 16 MiB for filesystem and loader overhead.
It credits no space from future bootloader cleanup and conservatively includes
the currently selected ordinary generations plus the replacement. A refusal
can therefore occur before the filesystem is literally full.

Missing metadata, missing boot inputs, separate XBOOTLDR layouts, dynamic initrd
secret appenders, and extra-initrd extensions require manual inspection instead
of an optimistic estimate. Build the replacement from this revision and check
that `python3` is available on the rescue host. New rescue images include it.
No secret values are read or embedded by the preflight.

If the budget does not fit, the command stops without deleting a profile,
snapshot, or ESP file. Record the reported required and available bytes.
Identify obsolete rollback profiles and their unreferenced ESP payloads, then
request approval for that exact retirement before cleaning anything up.
Keep a known-good bootable generation, its store closure, and the ESP backup.
Retiring a profile alone does not free its old ESP payloads. Recheck after any
approved cleanup. Keep other profile and ESP writers idle during the check and
installation so the measured inputs remain valid.

The Linux regression suite boots an isolated NixOS test VM, then runs the real
recovery command with real Nix profiles and a bounded temporary filesystem.
The VM avoids dependence on the runner's unprivileged-namespace policy without
changing that policy. Hardware inspection and the installer are isolated
substitutes. It checks first use, capacity refusal
before mutation, retained and shared payloads, copy headroom, generation limits,
unsupported initrds, and rollback roots after installer failure and real GC:

```sh
nix build .#checks.x86_64-linux.unas-recovery --no-link
```

This does not boot firmware, write a physical ESP, or activate the NAS.

## Verify the installed system

After reconnecting as `emiller`, confirm the running system matches the build,
`sudo -n` works, both selected pool GUIDs match, and every declared data dataset
is mounted. Inspect failed units, `exportfs -v`, NFS firewall rules, and the SSH,
Tailscale, Syncthing, backup, and Time Machine services. Successful service
startup does not prove a remote backup completed or a client authenticated.

The 2026-11-03 UTC verification reboot returned without console intervention on
NixOS `26.11.20260714.18b9261`, kernel `6.18.38`. Both expected pool GUIDs and all
declared mounts were present. Systemd reported `running` with no failed units;
SSH worked over LAN and Tailscale, and agenix decrypted all three Restic files
during initrd activation. Before reboot, Znapzend finished the first local home
backup. Snapshot `2026-11-02-220000` had matching source/destination GUIDs for
`zroot/user/home` and all three child home datasets. This backs up home data,
not every dataset on the NVMe.

On the first upgrade, let Syncthing finish its LevelDB-to-SQLite migration
before restarting it. The recovered database migrated 1,468,831 files.
Home Manager's backup option does not cover unmanaged symlinks. The old
`.terminfo/g/ghostty` link was preserved as `.terminfo/g/ghostty.pre-unas-recovery`
before activation; its target file remains intact. Only terminal compatibility
data is installed, not the Ghostty application. Dconf activation is disabled on
this headless host.

The November 2026 recovery found that the existing R2 credentials return
`401 Unauthorized`, while the `restic` bucket still exists. Cloud backups remain
unverified until authorized credentials are provisioned. The existing
healthchecks.io hooks also return `OK (not found)` and do not establish working
monitoring. Do not create an empty replacement repository to hide these failures.

The recovered `monimiller` and `tdmiller` accounts had no usable password hashes.
Time Machine client authentication needs an operator-set password for
`monimiller`; do not invent one in the deployment configuration.

Automatic upgrades and Restic pruning are disabled during recovery. Retain
`system.stateVersion = "24.05"` even when upgrading packages. Review retention
and unattended updates separately after the recovered system is verified.

The `pre-recovery` profile is a rollback aid that still depends on the internal
root pool. It is not the proposed independent RAM-root recovery image. The
old configuration also lacks the restricted pool discovery above. Do not boot
it blindly with duplicate `datatank` names attached. Use the Lexar to inspect
pool identities and reinstall a verified configuration when recovery is needed.

The separately built RAM-root rescue payload needs 466,383,747 bytes even with
XZ compression. After deployment, the ESP had only 360,898,560 bytes free and
systemd-boot 261. The full rescue does not fit. Keep the Lexar; no permanent
rescue entry or ESP resizing was installed. A different storage layout needs
a separate plan. The 512 MiB ESP ends at sector 1050623 and the ZFS partition
starts at 1050624. `sfdisk --list-free` reports no usable free extent, so the ESP
cannot simply grow into adjacent free space.
