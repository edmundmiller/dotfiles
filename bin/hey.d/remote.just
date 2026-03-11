# Remote deployment commands using deploy-rs

# Remote host configurations
NUC_HOST := "nuc"
UNAS_HOST := "192.168.1.101"

# Deploy to any host
deploy HOST:
    @echo "=== Deploying to {{HOST}} ==="
    cd {{FLAKE_DIR}} && nix run .#deploy-rs -- .#{{HOST}}

# Deploy to NUC (primary remote deployment)
nuc:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Deploying to NUC ==="
    cd {{FLAKE_DIR}} && nix run .#deploy-rs -- .#nuc --skip-checks

    # openclaw-gateway uses X-RestartIfChanged=false to survive rebuilds.
    # Restart it after deploy-rs finishes (remote deploys are always safe).
    if ssh {{NUC_HOST}} "systemctl --user is-active openclaw-gateway.service" &>/dev/null; then
        echo "=== Restarting openclaw-gateway on NUC ==="
        ssh {{NUC_HOST}} "systemctl --user restart openclaw-gateway.service"
    fi

# Deploy to UNAS
unas:
    @echo "=== Deploying to UNAS ==="
    cd {{FLAKE_DIR}} && nix run .#deploy-rs -- .#unas --skip-checks

unas-ssh:
    @echo "Connecting to UNAS..."
    @ssh -t {{UNAS_HOST}}

# Alias for nuc
rebuild-nuc: nuc

# Dry-run deployment (check what would change)
deploy-dry HOST:
    @echo "=== Dry-run deploy to {{HOST}} ==="
    nix run .#deploy-rs -- .#{{HOST}} --dry-activate

# Test NUC configuration (dry-run)
nuc-test:
    @echo "=== Testing NUC Configuration (dry-run) ==="
    nix run .#deploy-rs -- .#nuc --dry-activate --skip-checks

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

# Push openclaw-workspace, bump flake input, push dotfiles, deploy on NUC.
openclaw-rollout DOTFILES_MSG="chore: bump openclaw-workspace":
    #!/usr/bin/env bash
    set -euo pipefail

    workspace="$HOME/.openclaw/workspace"
    dotfiles="{{FLAKE_DIR}}"

    echo "=== 1/4 Push openclaw-workspace ==="
    cd "$workspace"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "workspace repo dirty; commit/stash first"
        exit 1
    fi
    git pull --rebase
    git push

    echo "=== 2/4 Update openclaw-workspace input ==="
    cd "$dotfiles"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "dotfiles repo dirty; commit/stash first"
        exit 1
    fi
    nix flake update openclaw-workspace

    echo "=== 3/4 Commit + push dotfiles ==="
    if git diff --quiet -- flake.lock; then
        echo "flake.lock unchanged; skipping commit"
    else
        git add flake.lock
        git commit -m "{{DOTFILES_MSG}}"
    fi
    git pull --rebase
    git push

    echo "=== 4/4 Deploy on NUC ==="
    ssh {{NUC_HOST}} "cd ~/.config/dotfiles && git pull && hey re"
