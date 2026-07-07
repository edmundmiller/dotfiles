# Install/bootstrap references

This repo is a nix-darwin + NixOS flake. Keep upstream install/reference docs
linkable instead of copying them into always-loaded agent context.

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
