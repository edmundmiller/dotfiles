# NUC Remote Deployment Guide

This document describes how to deploy configuration changes to the NUC server from your Mac.

## Quick Start

```bash
# Deploy to NUC (will prompt for sudo password)
hey nuc

# Check NUC status
hey nuc-status

# SSH into NUC
hey nuc-ssh
```

## Architecture

The remote deployment uses **deploy-rs**:
- **Builds on NUC**: `remoteBuild = true` - no cross-compilation
- **Magic rollback**: Auto-reverts if SSH dies during deploy
- **Interactive sudo**: Requires password for security
- **Direct push**: Nix closure pushed via SSH (no GitHub roundtrip)

## Available Commands

### Deployment

- `hey nuc` - Deploy to NUC via deploy-rs
- `hey deploy HOST` - Deploy to any configured host
- `hey deploy-check` - Dry-run all deploy configs

### Management

- `hey nuc-ssh` - SSH into the NUC
- `hey nuc-status` - Show system status and current generation
- `hey nuc-service <name>` - Check service status (e.g., `hey nuc-service docker`)
- `hey nuc-logs [unit] [lines]` - View system logs
- `hey nuc-rollback` - Roll back to previous generation
- `hey nuc-generations` - List all system generations

## Deployment Workflow

### Standard Deployment

1. Make changes to NUC configuration in `hosts/nuc/`
2. Run `hey nuc`
3. Enter sudo password when prompted
4. Verify deployment succeeded

```bash
# Example: Enable a new service
vim hosts/nuc/default.nix  # Set some-service.enable = true
hey nuc                    # Deploy
hey nuc-service some-service  # Verify it's running
```

### Testing Before Deployment

```bash
# Check flake syntax/evaluation
hey check

# Dry-run deploy (checks config without applying)
hey deploy-check

# If good, deploy
hey nuc
```

### Rollback

deploy-rs has **magic rollback**: if SSH becomes unreachable after activation, it automatically reverts to the previous generation.

Manual rollback:
```bash
hey nuc-rollback
```

## How It Works

### deploy-rs Configuration

Defined in `flake.nix`:
```nix
deploy.nodes.nuc = {
  hostname = "nuc";
  sshUser = "emiller";
  user = "root";
  interactiveSudo = true;
  remoteBuild = true;  # Build on NUC, not Mac
  
  profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos
    self.nixosConfigurations.nuc;
};
```

### SSH Configuration

Managed in `modules/shell/ssh.nix`:
```nix
"nuc" = {
  hostname = "192.168.1.222";
  user = "emiller";
  forwardAgent = true;
};
```

### What `hey nuc` Does

1. Evaluates NUC config locally
2. SSHs to NUC and builds the derivation there (`remoteBuild = true`)
3. Prompts for sudo password (`interactiveSudo = true`)
4. Activates new configuration
5. Confirms activation (magic rollback if this fails)

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection
ssh nuc

# If fails, test direct connection
ssh emiller@192.168.1.222

# Check 1Password SSH agent
echo $SSH_AUTH_SOCK
```

### Build Failures

```bash
# View logs on NUC
hey nuc-logs nixos-rebuild

# Roll back to last working generation
hey nuc-rollback
```

### Service Not Starting

```bash
# Check service status
hey nuc-service <service-name>

# View service logs
hey nuc-logs <service-name> 100
```

## See Also

- Main documentation: `/CLAUDE.md`
- SSH module: `modules/shell/ssh.nix`
- Remote commands: `bin/hey.d/remote.just`
- NUC configuration: `hosts/nuc/default.nix`
