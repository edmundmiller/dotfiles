use ./common.nu *

const NUC_HOST = "nuc"
const UNAS_HOST = "192.168.1.101"

def "main deploy" [host: string] {
  let ctx = (context)
  print $"=== Deploying to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)"
}

def remote-nuc-rebuild [] {
  print "=== remote NUC rebuild ==="
  print "=== remote rebuild uses the NUC checkout, so push/pull committed changes first ==="
  ^ssh $NUC_HOST 'cd ~/.config/dotfiles && /run/current-system/sw/bin/git pull --ff-only && hey re'
}

def "main nuc" [] {
  let ctx = (context)
  print "=== Deploying to NUC ==="
  cd $ctx.flake_dir

  let local_system = ((^nix eval --impure --raw --expr builtins.currentSystem | complete).stdout | str trim)
  if $local_system != "x86_64-linux" {
    print $"=== local system is ($local_system); using remote NUC rebuild ==="
    remote-nuc-rebuild
  } else {
    ^nix run .#deploy-rs -- .#nuc --skip-checks
  }

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


def validate-nuc-worktree-mode [mode: string] {
  let allowed = ["dry-activate" "test" "switch" "build" "vm"]
  if not ($mode in $allowed) {
    print -e $"error: mode must be one of: ($allowed | str join ', ')"
    error make {msg: "invalid nuc worktree deploy mode"}
  }
}

def "main nuc-worktree" [mode: string = "dry-activate"] {
  validate-nuc-worktree-mode $mode
  let ctx = (context)
  let remote_dir = $"/tmp/dotfiles-worktree-($env.USER? | default 'user')"

  print $"=== Syncing current worktree to NUC: ($ctx.flake_dir) -> ($NUC_HOST):($remote_dir) ==="
  ^ssh $NUC_HOST $"mkdir -p '($remote_dir)'"
  ^rsync -az --delete --delete-excluded --exclude .git/ --exclude result --exclude .direnv/ --exclude .pi/ --exclude node_modules/ --exclude .pytest_cache/ --exclude .ruff_cache/ --exclude .jscpd-report/ --exclude app.log --exclude error.log $"($ctx.flake_dir)/" $"($NUC_HOST):($remote_dir)/"

  if $mode == "vm" {
    print "=== Building NUC VM from synced worktree on NUC ==="
    ^ssh -t $NUC_HOST $"cd '($remote_dir)' && nix build .#nixosConfigurations.nuc.config.system.build.vm --show-trace"
    return
  }

  print $"=== Running nixos-rebuild ($mode) from synced worktree on NUC ==="
  if $mode == "build" {
    ^ssh -t $NUC_HOST $"cd '($remote_dir)' && nixos-rebuild build --flake .#nuc --show-trace"
  } else {
    ^ssh -t $NUC_HOST $"cd '($remote_dir)' && /run/wrappers/bin/sudo nixos-rebuild ($mode) --flake .#nuc --show-trace"
  }
}

def "main nuc-wt" [mode: string = "dry-activate"] {
  main nuc-worktree $mode
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

def scintillate-login-script [] {
  r#'
set -euo pipefail

echo "=== Scintillate Codex login ==="
echo "This stores Codex OAuth in /var/lib/hermes-scintillate/.hermes/auth.json."
echo "It does not copy or reuse ~/.codex/auth.json."
echo ""

docker exec -it hermes-agent-scintillate hermes auth add openai-codex --no-browser

echo ""
echo "=== Verifying direct openai-codex invocation ==="
docker exec hermes-agent-scintillate bash -lc 'timeout 180 hermes --provider openai-codex -m gpt-5.5 -z "Reply with exactly: OK"'

echo ""
echo "=== Re-running managed smoke check ==="
/run/wrappers/bin/sudo systemctl reset-failed hermes-scintillate-codex-smoke.service || true
/run/wrappers/bin/sudo systemctl start hermes-scintillate-codex-smoke.service
systemctl status hermes-scintillate-codex-smoke.service --no-pager -l | tail -30
'#
}

def "main login-scintillate" [] {
  let script = (scintillate-login-script)
  let local_hostname = (^hostname -s | str trim)

  if $local_hostname == $NUC_HOST {
    ^bash -lc $script
  } else {
    print $"=== Connecting to ($NUC_HOST) for Scintillate Codex login ==="
    ^ssh -t $NUC_HOST $script
  }
}

def betty-login-script [] {
  r#'
set -euo pipefail

sudo=/run/wrappers/bin/sudo
if [ ! -x "$sudo" ]; then
  sudo=sudo
fi

echo "=== Betty Codex login ==="
echo "This stores Codex OAuth in Betty-owned state:"
echo "  /var/lib/hermes-betty/.codex"
echo "  /var/lib/hermes-betty/.hermes/auth.json"
echo "It does not copy or reuse /home/emiller/.codex/auth.json."
echo ""
echo "Follow the printed OpenAI device-login URL and enter the one-time code."
echo "If OpenAI says the session is invalid, press Ctrl+C here and rerun hey login-betty;"
echo "then open the new URL/code in a private/incognito browser window."
echo ""

$sudo docker exec -it hermes-agent-betty bash -lc 'hermes auth add openai-codex --type oauth'

echo ""
echo "=== Verifying Betty openai-codex invocation ==="
$sudo docker exec hermes-agent-betty bash -lc 'hermes auth status openai-codex && timeout 180 hermes --provider openai-codex -m gpt-5.4-mini -z "Reply with exactly: OK"'

echo ""
echo "=== Verifying Scintillate still has independent Codex auth ==="
$sudo docker exec hermes-agent-scintillate bash -lc 'timeout 180 hermes --provider openai-codex -m gpt-5.5 -z "Reply with exactly: OK"'

echo ""
echo "=== Auth paths ==="
$sudo find /var/lib/hermes-betty -maxdepth 3 \( -path '*/.codex*' -o -name 'auth.json*' \) -printf '%M %u:%g %p -> %l\n' | sort
'#
}

def "main login-betty" [] {
  let script = (betty-login-script)
  let local_hostname = (^hostname -s | str trim)

  if $local_hostname == $NUC_HOST {
    ^bash -lc $script
  } else {
    print $"=== Connecting to ($NUC_HOST) for Betty Codex login ==="
    ^ssh -t $NUC_HOST $script
  }
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
