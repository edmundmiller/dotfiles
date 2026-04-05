# Runbook: Deploy to NUC

## Overview

The NUC is a NixOS server managed via **deploy-rs**. Deployment is triggered locally from the dotfiles repo — there is no CI-driven deployment.

## Prerequisites

- SSH access to `nuc` (configured in `~/.ssh/config` via home-manager)
- Tailscale connected (the NUC is on the tailnet)
- Clean working tree recommended (`git stash` uncommitted work)

## Deploy

```bash
# Standard deployment
hey nuc

# Or explicitly via deploy-rs
cd ~/.config/dotfiles
nix run .#deploy-rs -- .#nuc --skip-checks
```

## Dry Run (Preview Changes)

```bash
hey deploy-dry nuc
# Or
nix run .#deploy-rs -- .#nuc --dry-activate --skip-checks
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

### Deploy-rs magic rollback triggered

Deploy-rs has automatic rollback if the new configuration fails health checks. Check:

```bash
ssh nuc "sudo journalctl -u deploy-rs-activate -n 50"
```

### Service failed to start after deploy

```bash
# Check the service journal
ssh nuc "sudo journalctl -u <service-name> --since '5 minutes ago'"
# Roll back while investigating
hey nuc-rollback
```

### Gateway restart behavior after deploy

The active NUC gateway is `hermes-agent.service`, a system service that is restarted by activation during `hey nuc`, so no manual post-deploy restart is normally needed.

For older OpenClaw deployments only, the legacy user unit still uses `X-RestartIfChanged=false`, so you may need:

```bash
ssh nuc "systemctl --user try-restart openclaw-gateway.service"
```
