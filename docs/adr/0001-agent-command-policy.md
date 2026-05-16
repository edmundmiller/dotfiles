# ADR 0001: Agents use `hey` for guarded repo operations

## Status

Accepted

## Context

This repository manages macOS, NixOS, Home Manager, Homebrew, remote NUC deploys, and child flakes. Past agent sessions show a recurring pattern: when a guarded workflow fails, agents try lower-level commands such as direct `darwin-rebuild`, `nixos-rebuild` over SSH, direct `deploy-rs`, manual Nix cache/store deletion, direct Homebrew mutation, or raw skills flake updates.

Those commands bypass repo-specific checks, rollback semantics, host-awareness rules, and lock synchronization. One direct NixOS boot/reboot path left the NUC offline, so relying on prompt guidance alone is insufficient.

## Decision

`hey` is the supported interface for routine agent-initiated repo operations that mutate or deploy system state.

Agents must use or improve `hey` instead of invoking lower-level tools directly for:

- Darwin rebuilds: use `hey re` / `hey rebuild`.
- NUC/NixOS deploys: use `hey nuc`, `hey deploy *`, or `hey deploy-dry *`.
- Garbage collection/cleanup: use `hey gc` or add a targeted `hey` command.
- Skills catalog updates: use `hey skills-update` / `hey skills-sync`.
- Homebrew changes: edit Nix/darwin config and run `hey re`.

The Pi permission policy enforces this by denying common bypass patterns in `config/pi/pi-permissions.jsonc`.

## Consequences

- Agents get fast feedback when they attempt unsafe shortcuts.
- New legitimate workflows should be added to `hey` rather than repeated ad hoc.
- Expert one-off recovery commands may still require a human or an explicit policy exception.
- `pi-permission-system` remains the authoritative command gate for Pi agents.
