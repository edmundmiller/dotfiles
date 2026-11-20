---
purpose: Route Meshify recovery and preserve its former hardware and storage record.
applies_to: Meshify desktop recovery or historical hardware and disk inspection.
entrypoint: Read omarchy/README.md for the supported recovery interface.
verification: Run the Omarchy temporary-home recovery drill without activating the host.
update_when: Meshify recovery ownership or retained hardware evidence changes.
---

# Meshify

[Omarchy recovery](omarchy/README.md) is the supported desktop configuration.
The former GNOME/NixOS fallback is retired. This directory has no `default.nix`
and does not export a `nixosConfigurations.meshify` host.

`hardware-configuration.nix` and `disko.nix` preserve the former CPU, device,
monitor and ZFS layout record. They are historical evidence, not an installation
recipe for the current Omarchy system. Do not run disko against the live disks
from this record. The removed host composition remains in Git history.
