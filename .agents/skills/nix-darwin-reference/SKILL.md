---
name: nix-darwin-reference
description: >
  This skill should be used when editing nix-darwin or Darwin-specific Nix configuration in this dotfiles repo, troubleshooting darwin-rebuild failures, looking up macOS module options, bootstrapping a Mac with Lix/Nix, or using legacy nix-build during nix-darwin work.
---

# nix-darwin reference workflow

Use this skill for Darwin/macOS Nix work in this repo. Keep it out of the global agent rules: this is reference workflow, not behavior that belongs in every prompt.

## First checks

- Verify the host before host-specific rebuilds or Darwin/NixOS decisions: `hostname` and `uname -a`.
- Edit repo sources, not generated targets. Runtime files under `~/.config`, `~/.claude`, `~/.pi`, and similar paths are usually Nix-store symlinks.
- Prefer repo wrappers for validation: `hey check` for current Darwin host, `hey re` or full `darwin-rebuild` for local rebuilds.
- Avoid generic `nix flake check` on macOS in this repo because it evaluates NUC outputs and can hit known cross-system noise.

## Primary references

Use the narrowest reference that answers the question:

| Need                               | Reference                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------ |
| nix-darwin modules/options         | `darwin-help`, `man 5 configuration.nix`, or https://nix-darwin.github.io/nix-darwin/manual/index.html |
| nix-darwin install/bootstrap       | https://github.com/nix-darwin/nix-darwin                                                               |
| Lix install/upgrade on macOS/Linux | https://lix.systems/install/#on-any-other-linuxmacos-system                                            |
| Legacy `nix-build` behavior        | https://nix.dev/manual/nix/2.34/command-ref/nix-build.html                                             |

## Option lookup order

1. Use local docs first when available:
   - `darwin-help` for browser-based reference.
   - `man 5 configuration.nix` for terminal lookup.
2. Use the online nix-darwin reference when local docs are unavailable or stale.
3. Search this repo for existing patterns before adding a second convention.
4. Use source-level nix-darwin docs only when option reference docs are not enough.

## Install notes

- nix-darwin requires a Nix implementation; Nix and Lix are both supported.
- The nix-darwin README recommends the Lix installer for new macOS installs because the official Nix installer has no automated macOS uninstaller and manual removal is complex.
- nix-darwin can later manage the Nix package used by the system. To keep Lix, set `nix.package = pkgs.lix` in configuration.
- Flake-based nix-darwin installs use `darwin-rebuild switch`; before `darwin-rebuild` is installed, bootstrap with `sudo nix run nix-darwin/<branch>#darwin-rebuild -- switch`.

## `nix-build` notes

Use `nix-build` only when a legacy/channel workflow needs it. Prefer `nix build` or repo wrappers for normal flake work.

Important details from the Nix manual:

- `nix-build` is distinct from `nix build`; use `man nix3-build` or `nix build --help` for the modern command.
- Successful `nix-build` creates `result` symlinks by default, which become GC roots until removed.
- `--no-out-link` avoids creating the symlink and GC root.
- Common useful flags: `-A/--attr`, `--arg`, `--argstr`, `--dry-run`, `--out-link`.
