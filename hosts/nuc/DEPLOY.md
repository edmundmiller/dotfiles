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

The remote deployment system:
- **Builds on NUC**: Configuration is built on the target system (not cross-compiled)
- **Uses SSH**: Leverages 1Password SSH agent for authentication
- **Auto-syncs**: Pushes changes to GitHub, pulls on NUC, then rebuilds
- **Interactive sudo**: Requires your password for `nixos-rebuild` (security best practice)

## Available Commands

### Deployment

- `hey nuc` - Full deploy (push, pull, rebuild)
- `hey rebuild-nuc` - Alias for `hey nuc`
- `hey nuc-test` - Test configuration without adding to boot menu

### Management

- `hey nuc-ssh` - SSH into the NUC
- `hey nuc-status` - Show system status and current generation
- `hey nuc-service <name>` - Check service status (e.g., `hey nuc-service docker`)
- `hey nuc-logs [unit] [lines]` - View system logs
- `hey nuc-rollback` - Roll back to previous generation
- `hey nuc-generations` - List all system generations

### Advanced

- `hey nuc-local` - Build NUC config locally (slow on ARM Mac, useful for testing)

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
# Test locally (check for syntax errors)
hey check

# Test on NUC (activate but don't add to boot menu)
hey nuc-test

# If good, make it permanent
hey nuc
```

### Rollback on Issues

```bash
# Quick rollback to previous generation
hey nuc-rollback

# Or choose a specific generation
hey nuc-generations  # Find the generation number
hey nuc-ssh
sudo nixos-rebuild switch --rollback --flake .#nuc --profile-name system-<generation>
```

## How It Works

### 1. SSH Configuration

Managed in `modules/shell/ssh.nix`:
```nix
"nuc" = {
  hostname = "192.168.1.222";
  user = "emiller";
  forwardAgent = true;
};
```

### 2. Repository Sync

- Changes pushed to `github.com/edmundmiller/dotfiles` (main branch)
- NUC clones/updates from GitHub at `~/dotfiles-deploy`
- Ensures Mac and NUC are always in sync

### 3. Remote Build

The `hey nuc` command:
1. Pushes local commits to GitHub (`jj git push`)
2. SSHs to NUC with TTY allocation (`ssh -t`)
3. Updates repository on NUC (`git pull`)
4. Runs `sudo nixos-rebuild switch --flake .#nuc`
5. Prompts for your sudo password interactively

### 4. Build Location

**Remote builds** (default):
- Fast: Builds on native x86_64 hardware
- Simple: No cross-compilation complexity
- Secure: Requires interactive sudo password

**Local builds** (`hey nuc-local`):
- Slow: ARM Mac cross-compiling to x86_64
- Useful: For testing without deploying
- Optional: Not needed for normal workflow

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connection
ssh nuc

# If fails, test direct connection
ssh emiller@192.168.1.222

# Check 1Password SSH agent
echo $SSH_AUTH_SOCK
# Should point to: ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

### Repository Not Found

```bash
# Manually set up repository
ssh nuc
git clone https://github.com/edmundmiller/dotfiles.git ~/dotfiles-deploy
```

The `hey nuc` command will automatically clone on first run.

### Sudo Password Issues

The deployment requires your password for security. This is intentional and recommended.

**If you want passwordless deployment** (less secure), see Phase 6 below.

### Build Failures

```bash
# Check what changed
hey nuc-ssh
cd ~/dotfiles-deploy
git log -5 --oneline

# View build logs
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

# SSH in and debug
hey nuc-ssh
sudo systemctl status <service-name>
journalctl -u <service-name> -n 100
```

## Future Enhancements (Phase 6)

### Optional: Passwordless Deployment

To enable passwordless `nixos-rebuild` (less secure):

1. Add to `hosts/nuc/default.nix`:
```nix
security.sudo.extraRules = [{
  users = [ "emiller" ];
  commands = [{
    command = "/run/current-system/sw/bin/nixos-rebuild";
    options = [ "NOPASSWD" ];
  }];
}];
```

2. Deploy once with password: `hey nuc`
3. Future deployments won't need password

**Trade-off**: Convenience vs. security. Current approach (password required) is more secure.

## See Also

- Main documentation: `/CLAUDE.md`
- SSH module: `modules/shell/ssh.nix`
- Remote commands: `bin/hey.d/remote.just`
- NUC configuration: `hosts/nuc/default.nix`
