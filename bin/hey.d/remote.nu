use ./common.nu *

const NUC_HOST = "nuc"
const UNAS_HOST = "192.168.1.101"

def "main deploy" [host: string] {
  let ctx = (context)
  print $"=== Deploying to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)"
}

def "main nuc" [] {
  let ctx = (context)
  print "=== Deploying to NUC ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- .#nuc --skip-checks

  print "=== post-deploy gateway restart check on NUC ==="
  ^ssh $NUC_HOST '
    if systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
      echo "hermes-agent.service is system-managed; no extra restart needed"
    elif systemctl --user list-unit-files openclaw-gateway.service >/dev/null 2>&1; then
      echo "legacy openclaw-gateway.service detected; try-restarting"
      systemctl --user try-restart openclaw-gateway.service
    else
      echo "no gateway restart hook needed"
    fi
  '
}

def "main unas" [] {
  let ctx = (context)
  print "=== Deploying to UNAS ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- .#unas --skip-checks
}

def "main unas-ssh" [] {
  print "Connecting to UNAS..."
  ^ssh -t $UNAS_HOST
}

def "main rebuild-nuc" [] {
  main nuc
}

def "main deploy-dry" [host: string] {
  let ctx = (context)
  print $"=== Dry-run deploy to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)" --dry-activate
}

def "main nuc-test" [] {
  let ctx = (context)
  print "=== Testing NUC Configuration (dry-run) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- .#nuc --dry-activate --skip-checks
}

def "main deploy-check" [] {
  let ctx = (context)
  print "=== Checking all deploy configurations ==="
  cd $ctx.flake_dir
  ^nix flake check
}

def "main nuc-ssh" [] {
  print "Connecting to NUC..."
  ^ssh -t $NUC_HOST
}

def "main nuc-status" [] {
  print "=== NUC System Status ==="
  ^ssh $NUC_HOST '
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime)"
    echo ""
    echo "Current Generation:"
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1
  '
}

def "main nuc-service" [service: string] {
  print $"Checking ($service) on NUC..."
  ^ssh $NUC_HOST $"systemctl status ($service)"
}

def "main nuc-logs" [unit: string = "", lines: int = 50] {
  if ($unit | is-empty) {
    ^ssh $NUC_HOST $"sudo journalctl -n ($lines)"
  } else {
    ^ssh $NUC_HOST $"sudo journalctl -u ($unit) -n ($lines)"
  }
}

def "main nuc-rollback" [] {
  print "Rolling back NUC to previous generation..."
  ^ssh -t $NUC_HOST "sudo nixos-rebuild --rollback switch"
}

def "main nuc-generations" [] {
  print "=== NUC System Generations ==="
  ^ssh $NUC_HOST "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"
}

def "main agents-rollout" [dotfiles_msg: string = "chore: bump agents-workspace"] {
  let ctx = (context)
  let workspace = ($env.HOME | path join ".openclaw" "workspace")
  let dotfiles = $ctx.flake_dir

  print "=== 1/4 Push agents-workspace ==="
  cd $workspace
  let ws_dirty = (^bash -lc "set -euo pipefail; ! git diff --quiet || ! git diff --cached --quiet" | complete)
  if $ws_dirty.exit_code == 0 {
    print -e "workspace repo dirty; commit/stash first"
    error make {msg: "workspace repo dirty"}
  }
  ^git pull --rebase
  ^git push

  print "=== 2/4 Update agents-workspace input ==="
  cd $dotfiles
  let df_dirty = (^bash -lc "set -euo pipefail; ! git diff --quiet || ! git diff --cached --quiet" | complete)
  if $df_dirty.exit_code == 0 {
    print -e "dotfiles repo dirty; commit/stash first"
    error make {msg: "dotfiles repo dirty"}
  }
  ^nix flake update agents-workspace

  print "=== 3/4 Commit + push dotfiles ==="
  let lock_changed = (^git diff --quiet -- flake.lock | complete)
  if $lock_changed.exit_code == 0 {
    print "flake.lock unchanged; skipping commit"
  } else {
    ^git add flake.lock
    ^git commit -m $dotfiles_msg
  }
  ^git pull --rebase
  ^git push

  print "=== 4/4 Deploy on NUC ==="
  ^ssh $NUC_HOST "cd ~/.config/dotfiles && git pull && hey re"
}
