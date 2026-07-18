---
type: System Configuration
title: Nix Dotfiles
description: Cross-platform Nix flake for personal macOS and NixOS hosts, shared modules, self-hosted services, managed agents, and secure deployment workflows.
resource: /flake.nix
tags: [nix, nixos, nix-darwin, dotfiles, infrastructure]
---

# Nix Dotfiles

This wiki maps a declarative Nix flake for two macOS machines and several NixOS hosts. It is a synthesis layer over the repository: use it to locate the appropriate subsystem and operating guard before changing configuration.

## Start here

- [Architecture](architecture.md) — how `flake.nix`, the root loader, platform bases, host definitions, and Home Manager compose evaluated systems.
- [Operations](operations.md) — safe use of `hey`, especially NUC remote evaluation, locking, verification, and rollback.
- [Services and agents](services-and-agents.md) — self-hosted NUC services, the managed Hermes runtime, and guarded Obsidian Sync.
- [Secrets and safety](secrets-and-safety.md) — agenix/opnix responsibilities, secret-safe handling, and Betty automation boundaries.

## What it manages

The flake defines Linux (`x86_64-linux`) and Apple Silicon (`aarch64-darwin`) package sets and applies repository overlays. It emits:

| Area                 | Configurations / role                                                                                           | Source of truth                                         |
| -------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| macOS                | `MacTraitor-Pro` (`mactraitorpro`) and `Seqeratop` (`seqeratop`, also aliased as `L19W56QXR4`)                  | `flake.nix`, `hosts/mactraitorpro/`, `hosts/seqeratop/` |
| NixOS                | `nuc` home server, `unas` NAS, and `meshify` workstation                                                        | `flake.nix`, `hosts/`                                   |
| Deployment           | deploy-rs nodes for NUC and UNAS; NUC rebuilds normally use `hey`                                               | `flake.nix`, `bin/hey.d/remote.nu`                      |
| Shared configuration | platform-neutral modules, Home Manager aliases, package overlays, services, desktop configuration, and security | `default.nix`, `modules/`, `packages/`, `overlays/`     |

[Architecture](architecture.md) constructs these host outputs; host files enable and parameterize [services and agents](services-and-agents.md). [Operations](operations.md) is the supported lifecycle path for applying either type of output.

## Core conventions

- **Edit sources, not Nix store links.** Nix-managed files are read-only symlinks; rebuild after changing the repository.
- **Route before editing.** Root `AGENTS.md` directs work to the nearest nested instructions and canonical runbook. The root loader auto-discovers modules, so platform compatibility filters are consequential.
- **Use `hey` before raw Nix when a wrapper exists.** It is the repository lifecycle interface for rebuilds, checks, remote deployment, skills, and agent-quality commands.
- **Treat host identity as configuration.** The two Macs deliberately use different primary users (`emiller` and `edmundmiller`); do not normalize them casually.
- **Do not infer runtime health from evaluation.** Build/eval checks validate declaration structure; target-host service status and logs validate deployment.

## First checks

1. Determine the actual machine: `hostname` and `uname -a` are required before host-specific action.
2. Read root `AGENTS.md`, then the closest `AGENTS.md` for the target host or module.
3. For a local Darwin change, use `hey re` / `hey check` as appropriate. For NUC, begin with `hey nuc dry-activate` or `hey nuc-wt build`; do not evaluate the NUC system locally on a Mac.
4. When credentials are involved, follow [secrets and safety](secrets-and-safety.md): use a secret path or a non-secret success check, never print material.

## Important current focus

Recent Git history adds corruption tripwires for NUC Obsidian Headless Sync and repairs Betty’s runtime secret materialization. The intended sync topology and stop-on-violation behavior are documented in [services and agents](services-and-agents.md); the secret boundary and verification limits are documented in [secrets and safety](secrets-and-safety.md).

## Source references

- Repository orientation and basic installation: `README.md`
- Agent routing and non-negotiable guards: `AGENTS.md`
- Change-process quality gate: `AGENT_WORKFLOW.md`
- Flake outputs and checks: `flake.nix`
- Command surface: `bin/hey`

## Backlog

- **Package and overlay development** — `packages/`, `overlays/`; many independent package policies were deferred to keep this first map centered on system configuration and operating safety.
- **Desktop, shell, editor, and theme modules** — `modules/{desktop,shell,editors,themes}/`; broad user-environment domains need their own focused change map.
- **Individual service runbooks** — `modules/services/*/`; only cross-cutting service integration and the recently changed Obsidian workflow are included here.
