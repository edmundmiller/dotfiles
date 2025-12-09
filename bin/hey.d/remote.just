# Remote deployment commands for NixOS hosts

# Remote host configurations
NUC_HOST := "nuc"
NUC_USER := "emiller"
NUC_REPO := "dotfiles-deploy"

# Deploy to NUC (remote build and switch)
nuc MESSAGE="": _nuc-ensure-repo
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Deploying to NUC ==="
    echo ""
    
    # Push local changes to GitHub
    echo "Pushing changes to GitHub..."
    cd {{FLAKE_DIR}}
    jj git push --bookmark main 2>&1 || echo "No changes to push"
    
    echo ""
    echo "Connecting to NUC..."
    
    # Update repository and rebuild on NUC
    ssh -t {{NUC_HOST}} << 'ENDSSH'
    set -euo pipefail
    cd ~/{{NUC_REPO}}
    
    echo "Updating repository..."
    git fetch origin
    echo "Resetting to origin/main ($(git rev-parse --short origin/main))"
    git reset --hard origin/main
    git clean -fd
    
    echo ""
    echo "Current commit:"
    git log -1 --oneline
    
    echo ""
    echo "Rebuilding NixOS configuration..."
    sudo nixos-rebuild switch --flake .#nuc
    
    echo ""
    echo "=== Deployment complete! ==="
    ENDSSH

# Alias for nuc
rebuild-nuc MESSAGE="": (nuc MESSAGE)

# SSH into NUC
nuc-ssh:
    @echo "Connecting to NUC..."
    @ssh -t {{NUC_HOST}}

# Check NUC system status
nuc-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== NUC System Status ==="
    ssh {{NUC_HOST}} << 'ENDSSH'
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime)"
    echo ""
    echo "Current Generation:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1
    echo ""
    echo "Repository Status:"
    if [ -d ~/dotfiles-deploy ]; then
        cd ~/dotfiles-deploy
        echo "Branch: $(git branch --show-current)"
        echo "Commit: $(git log -1 --oneline)"
    else
        echo "Repository not cloned yet"
    fi
    ENDSSH

# Check service status on NUC
nuc-service SERVICE:
    @echo "Checking {{SERVICE}} on NUC..."
    @ssh {{NUC_HOST}} "systemctl status {{SERVICE}}"

# View NUC system logs
nuc-logs UNIT="" LINES="50":
    #!/usr/bin/env bash
    if [ -z "{{UNIT}}" ]; then
        ssh {{NUC_HOST}} "sudo journalctl -n {{LINES}}"
    else
        ssh {{NUC_HOST}} "sudo journalctl -u {{UNIT}} -n {{LINES}}"
    fi

# Roll back NUC to previous generation
nuc-rollback:
    @echo "Rolling back NUC to previous generation..."
    @ssh -t {{NUC_HOST}} "sudo nixos-rebuild --rollback switch"

# List NUC generations
nuc-generations:
    @echo "=== NUC System Generations ==="
    @ssh {{NUC_HOST}} "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"

# Test NUC configuration (build and activate, but don't add to boot menu)
nuc-test: _nuc-ensure-repo
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Testing NUC Configuration ==="
    echo ""
    
    # Push local changes
    cd {{FLAKE_DIR}}
    jj git push --bookmark main 2>&1 || echo "No changes to push"
    
    # Update and test on NUC
    ssh -t {{NUC_HOST}} << 'ENDSSH'
    set -euo pipefail
    cd ~/{{NUC_REPO}}
    
    echo "Updating repository..."
    git fetch origin
    echo "Resetting to origin/main ($(git rev-parse --short origin/main))"
    git reset --hard origin/main
    git clean -fd
    
    echo ""
    echo "Testing configuration (won't add to boot menu)..."
    sudo nixos-rebuild test --flake .#nuc
    ENDSSH

# Build NUC configuration locally (cross-compile from Mac)
nuc-local:
    @echo "Building NUC configuration locally..."
    @echo "Note: This will be slow on ARM Mac for x86_64 target"
    @cd {{FLAKE_DIR}} && nix build .#nixosConfigurations.nuc.config.system.build.toplevel

# Internal: Ensure NUC repository is set up
_nuc-ensure-repo:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if repository exists on NUC, clone if not
    if ! ssh {{NUC_HOST}} "[ -d ~/{{NUC_REPO}} ]"; then
        echo "Setting up repository on NUC..."
        ssh {{NUC_HOST}} "git clone https://github.com/edmundmiller/dotfiles.git ~/{{NUC_REPO}}"
    fi
