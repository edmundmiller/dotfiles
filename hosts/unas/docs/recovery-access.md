---
purpose: Build rescue media with the approved SSH login keys and retain portable owner access.
applies_to: Standalone UNAS rescue images, not the installed host configuration.
entrypoint: Build hosts/unas/recovery-image.nix on a Linux builder.
verification: Compare the image root authorized_keys with config/ssh/authorized-keys.nix.
update_when: The rescue builder, login inventory, or portable access procedure changes.
---

# Rescue SSH access

The default builder reads `config/ssh/authorized-keys.nix`. It includes all five
`ownerKeys` and both `unasMachineKeys`. The NUC key retains its source-address
restriction and forwarding restrictions. The Meshify key retains its existing
login grant. Agenix recipients, SSH host keys, and the work machine Seqeratop key
are not login grants and are not included.

Build from the repository root on Linux:

```sh
env -u NIXPKGS_CONFIG NIX_PATH= nix-build \
  --extra-experimental-features 'nix-command flakes' \
  --option extra-substituters https://install.determinate.systems \
  --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= \
  hosts/unas/recovery-image.nix --out-link /tmp/unas-rescue-result
```

The ISO is under `/tmp/unas-rescue-result/iso/`. Building source does not update
an existing USB stick. Writing a verified USB device requires separate operator
authorization, followed by a boot and login test of that physical media.
Access tests against an older USB do not verify this new image.

## Connect using an existing owner key

Connect Ethernet and boot the rescue media, then use:

```sh
ssh root@unas-rescue.local
```

Use the router's DHCP lease address if mDNS is unavailable. Verify a new rescue
host fingerprint at the console; do not disable host-key checking. SSH password
and keyboard-interactive authentication are disabled. The live ISO retains its
passwordless local console, not passwordless SSH. It does not import NAS pools,
partition disks, or install the host configuration automatically.

For portable access, use an existing approved owner credential on its current
device, such as the approved phone key or the existing security key through a
compatible SSH client. The authenticator and client must already support that
credential. Do not copy a private key, create a rescue credential, or broaden the
NUC key's source restriction. A different machine does not gain access merely
because it has an agenix recipient or host key. If no approved credential is
available, use the local console rather than weakening SSH policy.

## Inspect storage without changing it

Read `/etc/unas-recovery.txt` on the running image. Inspect `lsblk -f`, `findmnt`,
and `/dev/disk/by-id` before selecting any device. NVMe and bulk storage may use
Btrfs, older ZFS pools, or a mixture during migration. A separately authorized
Btrfs inspection mount needs `ro,rescue=nologreplay`. Add `subvolid=5` only when
explicitly inspecting the filesystem top level. `ro` alone can replay the tree log.
Preserve existing subvolumes, datasets, snapshots, host keys, secrets, and history.
Do not format storage or assume the checkout describes the physical disks.

## Optional explicit public-key file

The original builder's `--argstr publicKeysFile /absolute/path/to/keys.pub`
interface remains available for an explicitly approved replacement inventory.
It replaces the defaults, rather than appending to them. Blank lines and lines
starting with `#` are ignored; an empty result fails the image assertion.
Preserve each approved key's options, including the NUC source restriction.
The default build needs no separate hand-maintained public-key file.
