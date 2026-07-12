---
purpose: Deploy and verify the NUC from the dotfiles worktree.
applies_to: NUC builds, switches, rollbacks, and deployment recovery.
entrypoint: Run `hey nuc dry-activate`, then `hey nuc`.
verification: Confirm the generation and relevant systemd services on the NUC.
update_when: NUC authentication, build location, commands, or verification changes.
---

# Runbook: Deploy to NUC

## Overview

The NUC is a NixOS server managed from this dotfiles repo — there is no CI-driven deployment. `hey nuc` evaluates and builds on the NUC for consistent cross-platform behavior: when run off-NUC it syncs the current worktree to `nuc:/tmp/dotfiles-worktree-$USER` and runs `nixos-rebuild` there; when run on the NUC it runs a local `nixos-rebuild`. NUC rebuilds pass `--max-jobs 1` to keep builds stable on the small host.

## Prerequisites

- SSH access to `nuc` (configured in `~/.ssh/config` via home-manager)
- Tailscale connected (the NUC is on the tailnet)
- `/var/lib/opnix/secrets/githubNixToken` materialized by `opnix-secrets.service`
- Clean working tree recommended (`git stash` uncommitted work)

Private `github:` flake inputs use `nix-private-github`. It reads the root-only
opnix credential and supplies Nix `access-tokens` without logging the token.
`hey nuc`, local NUC `hey re`, and `nixos-upgrade.service` use this wrapper.
Darwin `hey re` obtains the same narrow credential from the local `gh` keyring.

## Deploy

```bash
# Standard deployment
hey nuc

# Preview from the same remote-evaluation path
hey nuc dry-activate
```

## Dry Run (Preview Changes)

```bash
hey nuc dry-activate
# Equivalent compatibility aliases:
hey deploy-dry nuc
hey deploy-check
```

## Verify Deployment

After deploying, verify the NUC is healthy:

```bash
# Quick system status
hey nuc-status

# Check specific services
ssh nuc "systemctl status home-assistant"
ssh nuc "systemctl status hermes-agent.service"

# Legacy OpenClaw deployments only
ssh nuc "systemctl --user status openclaw-gateway.service"

# Check current generation
ssh nuc "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3"

# View recent logs for a service
hey nuc-logs home-assistant.service 30
```

## Rollback

If the deployment causes issues:

```bash
# Roll back to previous generation
hey nuc-rollback
# Or via SSH
ssh nuc "sudo nixos-rebuild --rollback switch"
```

## Common Issues

### SSH connection refused

- Check Tailscale: `tailscale status | grep nuc`
- The NUC may be rebooting after a kernel update

### Service failed to start after deploy

```bash
# Check the service journal
ssh nuc "sudo journalctl -u <service-name> --since '5 minutes ago'"
# Roll back while investigating
hey nuc-rollback
```

### Private flake authentication fails

```bash
ssh nuc "sudo test -s /var/lib/opnix/secrets/githubNixToken"
ssh nuc "sudo systemctl restart opnix-secrets.service"
```

The source reference is `op://Agents/GH PA dotfiles flake/credential`. Never
print the materialized value. Verify access through the wrapper:

```bash
ssh nuc "sudo nix-private-github nix flake metadata github:edmundmiller/agents-workspace/main"
```

### Gateway restart behavior after deploy

The active NUC gateway is `hermes-agent.service`, a system service that is restarted by activation during `hey nuc`, so no manual post-deploy restart is normally needed.

For older OpenClaw deployments only, the legacy user unit still uses `X-RestartIfChanged=false`, so you may need:

```bash
ssh nuc "systemctl --user try-restart openclaw-gateway.service"
```
