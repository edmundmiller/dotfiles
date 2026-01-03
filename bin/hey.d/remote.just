# Remote deployment commands using deploy-rs

# Remote host configurations
NUC_HOST := "nuc"

# Deploy to any host
deploy HOST:
    @echo "=== Deploying to {{HOST}} ==="
    deploy .#{{HOST}} --interactive-sudo

# Deploy to NUC (primary remote deployment)
nuc:
    @echo "=== Deploying to NUC ==="
    deploy .#nuc --interactive-sudo

# Alias for nuc
rebuild-nuc: nuc

# Dry-run deployment (check what would change)
deploy-dry HOST:
    @echo "=== Dry-run deploy to {{HOST}} ==="
    deploy .#{{HOST}} --dry-activate

# Test NUC configuration (dry-run)
nuc-test:
    @echo "=== Testing NUC Configuration (dry-run) ==="
    deploy .#nuc --dry-activate

# Check all deploy configurations
deploy-check:
    @echo "=== Checking all deploy configurations ==="
    nix flake check

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
