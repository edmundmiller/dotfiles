---
name: nixos-usb-recovery
description: "Recover or rebuild an installed NixOS system from a NixOS USB/live ISO. Use for boot failures, broken generations, bootloader repairs, or rescue rebuilds."
---

# NixOS USB Recovery

Use this skill when repairing an installed NixOS system from a NixOS USB/live environment. The goal is to recover the existing installation in place: mount the target system, inspect generations/configuration, rebuild or repair, then reboot safely.

## When to use

- The machine is booted into a NixOS installer/live USB for rescue work.
- A NixOS generation, boot entry, activation script, or package change broke boot.
- You need to build a new generation for the installed system without reinstalling.
- You need to repair bootloader entries, profile symlinks, or `/boot` contents.

## Safety principles

- Do not reinstall unless the user explicitly asks.
- Do not assume device names, pool names, hostnames, or users.
- Prefer inspection before mutation: identify disks, filesystems, mountpoints, and boot entries first.
- Keep a note of every mount and symlink you change so you can undo or explain it.
- Use pinned flake refs or the user's requested source when rebuilding.
- Treat secrets and SSH keys carefully; do not print private key contents.

## Quick recovery flow

1. **Confirm live environment and network access**

   ```bash
   hostname
   ip addr
   lsblk -f
   findmnt
   ```

   If working remotely, confirm SSH stays available before starting a long rebuild.

2. **Identify the installed system**

   Inspect disks and filesystems without assuming names:

   ```bash
   lsblk -f
   sudo blkid
   sudo zpool import 2>/dev/null || true
   sudo btrfs filesystem show 2>/dev/null || true
   ```

   Look for the installed root filesystem, Nix store filesystem, home datasets, and EFI System Partition.

3. **Import or unlock storage if needed**

   ZFS example, replacing placeholders with discovered names:

   ```bash
   sudo zpool import -N -R /mnt <pool>
   sudo zfs list
   ```

   LUKS example:

   ```bash
   sudo cryptsetup open /dev/disk/by-uuid/<uuid> <name>
   ```

4. **Mount the installed system under `/mnt`**

   Use discovered devices/datasets. Examples:

   ```bash
   sudo mount /dev/disk/by-uuid/<root-uuid> /mnt
   sudo mkdir -p /mnt/nix /mnt/boot /mnt/home
   sudo mount /dev/disk/by-uuid/<nix-uuid> /mnt/nix        # if separate
   sudo mount /dev/disk/by-uuid/<efi-uuid> /mnt/boot       # or /mnt/boot/efi
   ```

   ZFS example:

   ```bash
   sudo zfs mount <pool>/<root-dataset>
   sudo mkdir -p /mnt/nix /mnt/boot
   sudo zfs mount <pool>/<nix-dataset>
   sudo mount /dev/disk/by-uuid/<efi-uuid> /mnt/boot
   ```

   Verify before continuing:

   ```bash
   findmnt -R /mnt
   test -e /mnt/etc/NIXOS || echo "Warning: /mnt does not look like NixOS root"
   test -d /mnt/nix/store || echo "Warning: Nix store is not mounted"
   ```

5. **Inspect generations and boot entries**

   ```bash
   ls -l /mnt/nix/var/nix/profiles/system*
   find /mnt/boot -maxdepth 3 -type f \( -name '*.conf' -o -name 'loader.conf' \) -print
   cat /mnt/boot/loader/loader.conf 2>/dev/null || true
   ls /mnt/boot/loader/entries 2>/dev/null || true
   ```

   If the task is a rollback, update the boot default and system profile only after confirming the target generation exists.

6. **Prepare for `nixos-enter` or rebuild**

   Ensure DNS works inside the installed root if the rebuild fetches inputs:

   ```bash
   sudo rm -f /mnt/etc/resolv.conf
   sudo cp -L /etc/resolv.conf /mnt/etc/resolv.conf
   ```

   Enter the installed environment when activation scripts or installed paths matter:

   ```bash
   sudo nixos-enter --root /mnt
   ```

7. **Rebuild or repair**

   For a new generation from a flake:

   ```bash
   sudo nixos-enter --root /mnt -c \
     'nixos-rebuild boot --refresh --flake <flake-ref>#<host>'
   ```

   If private flake inputs are fetched over SSH, pass an installed deploy key or agent deliberately:

   ```bash
   sudo nixos-enter --root /mnt -c \
     'env GIT_SSH_COMMAND="ssh -i /home/<user>/.ssh/<key> -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
      nixos-rebuild boot --refresh --flake <flake-ref>#<host>'
   ```

   Use `boot` for rescue work when you want the new generation selected on next boot without switching live services in the USB environment. Use `switch` only when you intentionally want activation inside the entered system.

8. **Verify the installed result**

   ```bash
   readlink -f /mnt/nix/var/nix/profiles/system
   cat /mnt/boot/loader/loader.conf 2>/dev/null || true
   ls -lt /mnt/boot/loader/entries 2>/dev/null | head
   sudo nixos-enter --root /mnt -c 'nixos-version; systemctl --version | head -1'
   ```

   If the repair was for a specific command or package, test it from `nixos-enter`:

   ```bash
   sudo nixos-enter --root /mnt -c '<command> --help | head'
   ```

9. **Unmount and reboot safely**

   ```bash
   sync
   sudo umount -R /mnt || true
   sudo zpool export <pool> 2>/dev/null || true
   sudo reboot
   ```

   If a pool export says it is busy, do not panic. Run `findmnt -R /mnt`, close shells using `/mnt`, run `sync`, and document the busy export if rebooting anyway.

## Common repair patterns

### Build a fixed generation instead of rolling back

Use this when the user has already fixed the flake/config and wants that fix deployed:

```bash
sudo nixos-enter --root /mnt -c \
  'nixos-rebuild boot --refresh --flake <flake-ref>#<host>'
```

Then verify the new generation number, boot default, and the fixed command/package.

### Select a known-good generation

Use only when rollback is requested or rebuilding is not possible:

```bash
ls -l /mnt/nix/var/nix/profiles/system-*-link
sudo ln -sfn /nix/var/nix/profiles/system-<N>-link /mnt/nix/var/nix/profiles/system
sudo sed -i 's/^default .*/default nixos-generation-<N>.conf/' /mnt/boot/loader/loader.conf
```

Verify the entry exists before changing the default:

```bash
test -f /mnt/boot/loader/entries/nixos-generation-<N>.conf
```

### Repair systemd-boot entries

If the installed profile is correct but boot entries are missing or stale, rebuild boot files from the installed environment:

```bash
sudo nixos-enter --root /mnt -c 'nixos-rebuild boot --install-bootloader --flake <flake-ref>#<host>'
```

## Post-boot checks

After removing the USB and booting from disk, SSH into the installed system and check:

```bash
readlink /nix/var/nix/profiles/system
systemctl is-system-running || true
systemctl --failed --no-pager
systemctl is-active sshd tailscaled 2>/dev/null || true
```

If a service initially failed during boot but later recovered, use `systemctl reset-failed` only after confirming the service is now healthy.

## Final report checklist

Summarize:

- How the installed system was identified and mounted.
- What generation or flake ref was deployed.
- Any bootloader/profile changes made.
- Verification performed before reboot and after boot.
- Any remaining failed units or follow-up work.
