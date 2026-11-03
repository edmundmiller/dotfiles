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

## Key files

- `default.nix` — host imports + enabled modules
- `disko.nix` — disk + ZFS pool layout
- `nas.nix` — NFS exports + firewall
- `modules/time-machine.nix` — Time Machine via netatalk
- `backups.nix` — restic backup job
- `users.nix` — local users/groups

## Notes

- Host may be powered off / stale if unused for long periods.
- If deploy fails with SSH refused, enable sshd from local console first.

## Headless recovery USB

For the firmware key sequence, SSH connection, and remote-console options, see
[Boot UNAS from the Lexar rescue USB](docs/boot-recovery-usb.md).
For pool identities, guarded installation, and rollback precautions, see
[Redeploy UNAS without formatting its disks](docs/redeploy-from-rescue.md).

`recovery-image.nix` extends a pinned [Determinate NixOS ISO](https://docs.determinate.systems/guides/nixos-isos/)
independently of the host flake. Determinate Nix and `fh` are installed in the
live environment only. Supply a file containing the SSH public keys that should
have root access:

```bash
env -u NIXPKGS_CONFIG NIX_PATH= nix-build \
  --extra-experimental-features 'nix-command flakes' \
  --option extra-substituters https://install.determinate.systems \
  --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= \
  hosts/unas/recovery-image.nix --argstr publicKeysFile /absolute/path/to/keys.pub
```

Clearing the build's Nixpkgs environment prevents this host's overlays from
leaking into upstream packages. The cache options avoid compiling Determinate
Nix locally. The image keeps the LTS kernel entry because upstream's optional
latest-kernel entry disables ZFS.

The ISO is under `result/iso/`. It supports UEFI and legacy USB boot. After
writing it to a verified USB device, plug it into UNAS, connect Ethernet, and
select the USB in the firmware boot menu. Secure Boot must be disabled. The
default entry boots after five seconds and starts DHCP, SSH, and mDNS:

```bash
ssh root@unas-rescue.local
```

If mDNS is unavailable, find `unas-rescue` in the router's DHCP leases. SSH only
accepts the supplied keys; local console login is passwordless. The live system
generates fresh SSH host keys each boot, so verify a changed fingerprint at the
console rather than disabling host-key checking globally.

Booting this image does not install NixOS, format disks, or import NAS pools.
Inspect `lsblk -f`, `/dev/disk/by-id`, and `zpool import` over SSH before deciding
what to repair. The configured `zroot` pool contains home directories too, so
even the OS disk must not be wiped. `/etc/unas-recovery.txt` contains further
data-preservation notes. Do not run the host's disko formatting workflow during
recovery.
