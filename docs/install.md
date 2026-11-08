---
purpose: Route host installation and redeployment to existing configuration and safe provisioning.
applies_to: New host setup, existing host redeployment, and recovery installation.
entrypoint: Inspect the host configuration and its existing declarative disk layout.
verification: Validate scoped source, exact target devices, preservation, and each completed stage.
update_when: Host provisioning, redeployment, or disk execution policy changes.
---

# Install/bootstrap references

This repo is a nix-darwin + NixOS flake. Keep upstream install/reference docs
linkable instead of copying them into always-loaded agent context.

## NixOS host setup and redeployment

Before setting up a new host or redeploying an existing one, inspect its host
configuration and imports. Reuse or update the existing declarative disko layout,
including [hosts/unas/disko.nix](../hosts/unas/disko.nix) for UNAS. For a new host,
use a matching existing host configuration as the starting point. Keep partitions,
filesystem profiles, subvolumes, and mount policy in the host's disko configuration
rather than inventing a parallel imperative layout.

For configuration-only redeployment, use the host's supported `hey` command
without disk provisioning. A layout declaration, build, or redeployment request
does not authorize destructive disk operations.

When storage provisioning is explicitly authorized:

1. Validate exact device identities and current mounts. Verify preservation and
   recovery material outside every disk that the stage will rewrite.
2. Generate and inspect provisioning artifacts from the existing disko
   configuration, targeting only that stage's approved devices. During partial
   migrations, preserve other declared disks rather than running a blanket
   all-disks wipe. Accept each restored stage before advancing.
3. If narrow imperative cleanup is necessary, such as removing stale signatures,
   document its reason, exact commands, and approved device targets as an explicit
   exception. Keep cleanup separate from the generated provisioning stage and
   retain disko as the layout source of truth.

## macOS / nix-darwin

- nix-darwin repo and bootstrap guide:
  <https://github.com/nix-darwin/nix-darwin>
- nix-darwin option reference:
  <https://nix-darwin.github.io/nix-darwin/manual/index.html>
- Local nix-darwin docs after install:
  - `darwin-help`
  - `man 5 configuration.nix`
- Lix installer for new or existing Linux/macOS installs:
  <https://lix.systems/install/#on-any-other-linuxmacos-system>

The nix-darwin README recommends the Lix installer because the official Nix
installer does not include an automated uninstaller, and manual uninstallation
on macOS is complex. The Lix installer supports both flake-based and
channel-based setups.

The installer does not decide which Nix interpreter the system uses later:
nix-darwin manages the Nix installation by default and defaults to upstream
Nix. To keep Lix, set `nix.package = pkgs.lix` in configuration.

## Nix command references

- Legacy `nix-build` reference:
  <https://nix.dev/manual/nix/2.34/command-ref/nix-build.html>

Prefer flake-era `nix build` or this repo's `hey` wrappers for normal work.
Use `nix-build` only when a legacy/channel workflow needs it.

## NixOS USB recovery

<https://nixos.org/manual/nixos/stable/#sec-booting-from-usb-linux>

```bash
wget https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso
diskutil unmountDisk diskX
sudo dd if=<path-to-image> of=/dev/rdiskX bs=4m
```
