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
