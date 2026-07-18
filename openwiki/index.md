---
type: Documentation Index
title: "OpenWiki"
description: "Files and subdirectories in OpenWiki."
---

# Files

- [Flake and host composition](architecture.md) - How the dotfiles flake builds NixOS and nix-darwin systems from host definitions, auto-discovered modules, overlays, and Home Manager configuration.
- [Rebuild, deploy, and verification workflow](operations.md) - Safe command paths for local Darwin rebuilds and remote NUC deployment, including locking, stale-worktree protection, service verification, and rollback.
- [Nix Dotfiles](quickstart.md) - Cross-platform Nix flake for personal macOS and NixOS hosts, shared modules, self-hosted services, managed agents, and secure deployment workflows.
- [Secrets, runtime injection, and safety boundaries](secrets-and-safety.md) - Credential-management responsibilities for agenix and opnix, secret-safe validation, and the constrained runtime materialization used by NUC automation.
- [NUC services, managed agents, and Obsidian Sync safety](services-and-agents.md) - Service integration pattern for the NUC, boundaries for the Hermes agent runtime, and the hybrid Obsidian Sync topology with corruption tripwires.
