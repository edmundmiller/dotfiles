---
type: Architecture Overview
title: Flake and host composition
description: How the dotfiles flake builds NixOS and nix-darwin systems from host definitions, auto-discovered modules, overlays, and Home Manager configuration.
resource: /flake.nix
tags: [nix, architecture, hosts, home-manager]
---

# Flake and host composition

`flake.nix` is the composition root. It pins Nix inputs, creates Linux and Darwin package sets, exposes overlays and packages, and emits host configurations. The [operations workflow](operations.md) applies these outputs; host definitions use this composition to select [services and agents](services-and-agents.md).

## Outputs and host topology

| Platform                  | Hosts                                             | Construction                                                                      |
| ------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------- |
| NixOS (`x86_64-linux`)    | `nuc`, `unas`, `meshify`                          | `nixosConfigurations` maps host directories through `lib.my.mapHosts` / `mkHost`. |
| Darwin (`aarch64-darwin`) | `MacTraitor-Pro`, `Seqeratop`, alias `L19W56QXR4` | explicit `nix-darwin.lib.darwinSystem` definitions.                               |

`nuc` is the home server, `unas` is the storage/NAS host, and `meshify` is a desktop/workstation. The Macs differ deliberately: MacTraitor-Pro has primary user `emiller`; Seqeratop has primary user `edmundmiller`. `modules/options.nix` falls back to `system.primaryUser` when a rebuild runs under root, preventing the wrong Home Manager target.

Shared host profiles in `hosts/_home.nix` and `hosts/_server.nix` provide LAN/server defaults. NUC and UNAS are also `deploy-rs` nodes, but the repository’s preferred NUC activation path is documented in [operations](operations.md).

## Layering model

```text
flake.nix
  -> package sets + overlays + flake outputs
  -> root default.nix
      -> recursively discovered modules/ (platform-filtered)
      -> shared Nix, cache, environment, and Home Manager configuration
  -> host default.nix
      -> host hardware, identity, storage, and service enablement
  -> evaluated NixOS or nix-darwin system
```

`default.nix` imports Home Manager’s NixOS module only on Linux and recursively imports modules from `modules/`. Its explicit NixOS-only exclusions prevent Darwin evaluation from loading unsupported desktop, security, and system-service configuration. `isDarwin` is propagated via `_module.args` so modules can guard platform-specific options.

The base modules then set platform floors:

- `modules/nixos-base.nix` configures NixOS state version, boot/kernel defaults, automatic optimization, XDG session variables, and a fallback root filesystem.
- `modules/darwin-base.nix` configures the Nix daemon, automatic optimization, Darwin state version, and Home Manager use of global packages.
- `modules/options.nix` defines short aliases such as `home.file`, `home.configFile`, `home.dataFile`, `user.packages`, and `env`; these map to Home Manager rather than replacing it.

## Packages and inputs

The flake has separate `nixpkgs`, unstable, and Node-oriented package inputs. `mkPkgs` enables unfree packages and applies overlays. The default overlay exposes `unstable`, `node-lts`, and repository packages at `pkgs.my`; both Linux and Darwin outputs re-export selected `llm-agents` packages.

This architecture makes input or overlay changes cross-cutting: they can alter host evaluation, package selection, and [managed agent](services-and-agents.md) availability. Update `flake.lock` only through the repository’s intended workflow and use the relevant check surface.

## Change guidance

1. Start from the affected host and nearest `AGENTS.md`, not from all modules.
2. If adding a module, confirm it is safe for both platforms or add an evidence-based platform guard/filter.
3. Preserve host identity and primary-user logic; it affects paths, permissions, Home Manager, and secret access.
4. For NUC/UNAS storage or host imports, read their nested instructions before touching Disko, ZFS, backups, or deployment settings.
5. After a structural change, use [operations](operations.md) to select a target-appropriate build or activation check; local Darwin evaluation is not valid evidence for the NUC system.

## Key sources

`flake.nix`; `default.nix`; `modules/{options.nix,nixos-base.nix,darwin-base.nix}`; `lib/nixos.nix`; `hosts/{_home.nix,_server.nix}/`.
