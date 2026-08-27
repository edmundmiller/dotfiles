use ./common.nu *

const NUC_HOST = "nuc"
const UNAS_HOST = "192.168.1.101"

def "main deploy" [host: string] {
  let ctx = (context)
  print $"=== Deploying to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)"
}

def nuc-deploy-mode [hostname: string] {
  if $hostname == $NUC_HOST { "local" } else { "worktree-remote" }
}

def nuc-deploy-source [repository: string = "."] {
  let head = ((^git -C $repository rev-parse HEAD | complete).stdout | str trim)
  let base = ((^git -C $repository merge-base HEAD origin/main | complete).stdout | str trim)
  let worktree_status = (^git -C $repository status --porcelain=v1 --untracked-files=normal | complete)
  if ($head | is-empty) or ($base | is-empty) {
    error make {msg: "could not resolve NUC deploy source against origin/main"}
  }
  if $worktree_status.exit_code != 0 {
    error make {msg: "could not inspect NUC deploy source cleanliness"}
  }
  let short_hostname = if ($env.HOSTNAME? | default "" | is-empty) {
    ^hostname -s | str trim
  } else {
    $env.HOSTNAME | str trim
  }
  let owner = $"($env.USER? | default 'user')@($short_hostname)"
  let dirty = (($worktree_status.stdout | str trim | is-empty) == false)
  {head: $head, base: $base, owner: $owner, dirty: $dirty}
}

def require-clean-nuc-activation [source: record, mode: string] {
  if $source.dirty and ($mode in ["dry-activate" "test" "switch"]) {
    error make {msg: $"refusing ($mode) from a dirty worktree; commit the exact source before activating the NUC"}
  }
}

def nuc-deploy-source-args [source: record] {
  let override = if (($env.NUC_DEPLOY_ALLOW_STALE? | default "0") == "1") {
    ["--nuc-deploy-allow-stale"]
  } else {
    []
  }
  [
    $"--nuc-deploy-source-head=($source.head)"
    $"--nuc-deploy-source-base=($source.base)"
    $"--nuc-deploy-source-owner=($source.owner)"
  ] | append $override
}

def nuc-post-deploy-check [local: bool] {
  let script = '
    set -euo pipefail
    echo "=== post-deploy Hermes/gateway status ==="
    if systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
      echo "hermes-agent.service is system-managed"
      systemctl is-active hermes-agent.service || true
    else
      echo "no Hermes system service present"
    fi
    systemctl --no-pager --plain list-units "hermes*.service" || true
    echo ""
    echo "=== post-deploy Hermes runtime smoke ==="
    /run/wrappers/bin/sudo systemctl start hermes-runtime-smoke.service || true
    systemctl status hermes-runtime-smoke.service --no-pager -l || true
    journalctl -u hermes-runtime-smoke.service -n 80 --no-pager || true
  '
  if $local {
    ^bash -lc $script
  } else {
    ^ssh $NUC_HOST $script
  }
}

def "main nuc-hermes-smoke" [] {
  print "=== NUC Hermes runtime smoke ==="
  ^ssh $NUC_HOST "/run/wrappers/bin/sudo systemctl start hermes-runtime-smoke.service || true; systemctl status hermes-runtime-smoke.service --no-pager -l || true; journalctl -u hermes-runtime-smoke.service -n 80 --no-pager || true"
}

def nuc-local-rebuild [] {
  let ctx = (context)
  cd $ctx.flake_dir
  let source = (nuc-deploy-source $ctx.flake_dir)
  require-clean-nuc-activation $source "switch"
  let source_args = (nuc-deploy-source-args $source)

  print "=== NUC deploy mode: explicit local nixos-rebuild ==="
  with-sudo-path { ^sudo nix-private-github ...$source_args nixos-rebuild --flake $"($ctx.flake_dir)#nuc" --show-trace --accept-flake-config --max-jobs 1 switch }
  nuc-post-deploy-check true
}

def "main nuc" [mode: string = "auto", worktree_mode: string = "switch"] {
  let ctx = (context)
  cd $ctx.flake_dir

  let local_hostname = (^hostname -s | str trim)
  let local_system = ((^nix eval --impure --raw --expr builtins.currentSystem | complete).stdout | str trim)
  let worktree_modes = ["dry-activate" "test" "switch" "build" "vm"]
  let allowed_modes = ["auto" "dry-activate" "test" "switch" "build" "vm"]

  if $mode == "local" {
    print $"=== NUC deploy mode: local from ($local_hostname) (($local_system)) ==="
    nuc-local-rebuild
    return
  }

  if ($mode == "wt") or ($mode == "worktree") {
    print $"=== NUC deploy mode: worktree ($worktree_mode) from ($local_hostname) (($local_system)) ==="
    main nuc-worktree $worktree_mode
    return
  }

  if not ($mode in $allowed_modes) {
    print -e "error: hey nuc mode must be one of: auto, local, wt, worktree, dry-activate, test, switch, build, vm"
    error make {msg: "invalid hey nuc mode"}
  }

  if $mode in $worktree_modes {
    print $"=== NUC deploy mode: worktree ($mode) from ($local_hostname) (($local_system)) ==="
    main nuc-worktree $mode
    return
  }

  let deploy_mode = (nuc-deploy-mode $local_hostname)
  print $"=== NUC deploy mode: ($deploy_mode) from ($local_hostname) (($local_system)) ==="
  if $deploy_mode == "local" {
    nuc-local-rebuild
    return
  }

  print "=== evaluating and building on the NUC from a synced worktree ==="
  main nuc-worktree $worktree_mode
}

def validate-nuc-worktree-mode [mode: string] {
  let allowed = ["dry-activate" "test" "switch" "build" "vm"]
  if not ($mode in $allowed) {
    print -e $"error: mode must be one of: ($allowed | str join ', ')"
    error make {msg: "invalid nuc worktree deploy mode"}
  }
}

def nuc-worktree-configuration [configuration: string] {
  let allowed = [
    "nuc"
    "nuc-buzz-scintillate"
    "nuc-buzz-scintillate-finn"
    "nuc-buzz-scintillate-finn-amosburton"
    "nuc-buzz-scintillate-finn-amosburton-anne"
  ]
  if not ($configuration in $allowed) {
    print -e $"error: NUC worktree configuration must be one of: ($allowed | str join ', ')"
    error make {msg: "invalid NUC worktree configuration"}
  }
  $configuration
}

def nuc-worktree-rsync [source: string, destination: string] {
  ^rsync -az --delete --delete-excluded --filter "protect /.nuc-deploy-active" --exclude .git --exclude result --exclude .direnv/ --exclude .pi/ --exclude node_modules/ --exclude .venv/ --exclude __pycache__/ --exclude .pytest_cache/ --exclude .ruff_cache/ --exclude .jscpd-report/ --exclude app.log --exclude error.log $source $destination
}

def nuc-worktree-archive [source: string, revision: string] {
  let parsed = ($revision | parse -r '^(?<revision>[0-9a-f]{40})$')
  if ($parsed | is-empty) {
    error make {msg: "clean NUC snapshots require an exact 40-character lowercase Git revision"}
  }
  ^git -C $source archive --format=tar $revision
}

def nuc-worktree-sync [source: string, destination: string, revision: string, dirty: bool, host: string = ""] {
  if $dirty {
    let target = if ($host | is-empty) { $destination } else { $"($host):($destination)/" }
    nuc-worktree-rsync $"($source)/" $target
  } else if ($host | is-empty) {
    mkdir $destination
    nuc-worktree-archive $source $revision | ^tar --exclude=.nuc-deploy-active -xf - -C $destination
  } else {
    nuc-worktree-archive $source $revision | ^ssh $host $"tar --exclude=.nuc-deploy-active -xf - -C '($destination)'"
  }
}

def nuc-worktree-prune [script: string, user: string] {
  open --raw $script | ^ssh $NUC_HOST $"bash -s -- /tmp '($user)' 4"
}

def nuc-worktree-release-script [destination: string, user: string, root: string = "/tmp"] {
  $"function nuc_release {
  local release_status=0
  if ! rm -f '($destination)/.nuc-deploy-active'; then
    printf 'warning: failed to remove active NUC snapshot lease: ($destination)\\n' >&2
    release_status=1
  fi
  if ! bash '($destination)/bin/prune-nuc-deploy-snapshots' '($root)' '($user)' 5; then
    printf 'warning: failed to prune completed NUC snapshots after: ($destination)\\n' >&2
    release_status=1
  fi
  return \"$release_status\"
}
nuc_release"
}

def nuc-worktree-release [destination: string, user: string, host: string = "", root: string = "/tmp"] {
  let command = (nuc-worktree-release-script $destination $user $root)
  if ($host | is-empty) {
    ^bash -c $command
  } else {
    ^ssh $host $command
  }
}

def nuc-worktree-lifecycle-script [destination: string, user: string, command: string] {
  let release = (nuc-worktree-release-script $destination $user)
  $"set -euo pipefail
function cleanup {
  status=$?
  trap - EXIT
  set +e
  ($release)
  release_status=$?
  if [ \"$status\" -ne 0 ]; then
    exit \"$status\"
  fi
  exit \"$release_status\"
}
trap cleanup EXIT
($command)"
}

def nuc-worktree-lifecycle-command [destination: string, user: string, command: string] {
  let script = (nuc-worktree-lifecycle-script $destination $user $command)
  let encoded = ($script | encode base64)
  $"printf '%s' '($encoded)' | base64 --decode | bash"
}

def nuc-worktree-revision-command [destination: string, revision: string] {
  let parsed = ($revision | parse -r '^(?<revision>[0-9a-f]{40}(-dirty)?)$')
  if ($parsed | is-empty) {
    error make {msg: "NUC deploy revision must be a 40-character lowercase Git revision, optionally suffixed with -dirty"}
  }
  $"bash '($destination)/bin/write-nuc-deploy-revision' '($destination)' '($revision)'"
}

def nuc-worktree-prepare [source: string, destination: string, revision: string, dirty: bool, user: string, host: string = "", root: string = "/tmp"] {
  try {
    nuc-worktree-sync $source $destination $revision $dirty $host
    let command = (nuc-worktree-revision-command $destination $revision)
    if ($host | is-empty) {
      ^bash -c $command
    } else {
      ^ssh $host $command
    }
  } catch {|err|
    try {
      nuc-worktree-release $destination $user $host $root
    } catch {|cleanup_err|
      print -e $"warning: failed to release NUC snapshot after preparation error: ($cleanup_err.msg)"
    }
    error make $err
  }
}

def nuc-worktree-remote-dir [user: string, source: record] {
  let parsed_user = ($user | parse -r '^(?<user>[A-Za-z0-9._-]+)$')
  if ($parsed_user | is-empty) {
    error make {msg: "NUC deploy user must contain only letters, digits, dot, underscore, or hyphen"}
  }
  let state = if $source.dirty { "dirty" } else { "clean" }
  let suffix = $"($source.head)-($state)-((random uuid))"
  $"/tmp/dotfiles-worktree-($user)-($suffix)"
}

def "main nuc-worktree" [mode: string = "dry-activate", configuration: string = "nuc"] {
  validate-nuc-worktree-mode $mode
  let deploy_configuration = (nuc-worktree-configuration $configuration)
  let ctx = (context)
  let source = (nuc-deploy-source $ctx.flake_dir)
  require-clean-nuc-activation $source $mode
  let deploy_user = ($env.USER? | default "user")
  let remote_dir = (nuc-worktree-remote-dir $deploy_user $source)
  let revision = if $source.dirty { $"($source.head)-dirty" } else { $source.head }
  let prune_script = ($ctx.flake_dir | path join "bin" "prune-nuc-deploy-snapshots")

  print $"=== Syncing current worktree to NUC: ($ctx.flake_dir) -> ($NUC_HOST):($remote_dir) ==="
  print $"NUC_WORKTREE_REMOTE_DIR=($remote_dir)"
  nuc-worktree-prune $prune_script $deploy_user
  ^ssh $NUC_HOST $"mkdir -p '($remote_dir)'"
  ^ssh $NUC_HOST $"touch '($remote_dir)/.nuc-deploy-active'"
  nuc-worktree-prepare $ctx.flake_dir $remote_dir $revision $source.dirty $deploy_user $NUC_HOST

  if $mode == "vm" {
    print "=== Building NUC VM from synced worktree on NUC ==="
    let command = $"cd '($remote_dir)' && /run/wrappers/bin/sudo nix-private-github nix build .#nixosConfigurations.($deploy_configuration).config.system.build.vm --show-trace --accept-flake-config --max-jobs 1"
    ^ssh $NUC_HOST (nuc-worktree-lifecycle-command $remote_dir $deploy_user $command)
    return
  }

  print $"=== Running nixos-rebuild ($mode) for ($deploy_configuration) from synced worktree on NUC ==="
  if $mode == "build" {
    let command = $"cd '($remote_dir)' && /run/wrappers/bin/sudo nix-private-github nixos-rebuild build --flake .#($deploy_configuration) --show-trace --accept-flake-config --max-jobs 1"
    ^ssh $NUC_HOST (nuc-worktree-lifecycle-command $remote_dir $deploy_user $command)
  } else {
    let source_args = ((nuc-deploy-source-args $source) | str join " ")
    let command = $"cd '($remote_dir)' && /run/wrappers/bin/sudo nix-private-github ($source_args) nixos-rebuild ($mode) --flake .#($deploy_configuration) --show-trace --accept-flake-config --max-jobs 1"
    ^ssh $NUC_HOST (nuc-worktree-lifecycle-command $remote_dir $deploy_user $command)
    if ($mode == "switch") or ($mode == "test") {
      nuc-post-deploy-check false
    }
  }
}

def "main nuc-wt" [mode: string = "dry-activate", configuration: string = "nuc"] {
  main nuc-worktree $mode $configuration
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
  if $host == $NUC_HOST {
    main nuc dry-activate
    return
  }

  let ctx = (context)
  print $"=== Dry-run deploy to ($host) ==="
  cd $ctx.flake_dir
  ^nix run .#deploy-rs -- $".#($host)" --dry-activate
}

def "main nuc-test" [] {
  main nuc dry-activate
}

def "main deploy-check" [] {
  print "=== Checking NUC deploy path with remote dry-activate ==="
  main nuc dry-activate
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
echo "=== Re-running runtime smoke check ==="
hermes-runtime-smoke scintillate
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
$sudo docker exec hermes-agent-betty bash -lc 'hermes auth status openai-codex && timeout 180 hermes --provider openai-codex -m gpt-5.6-luna -z "Reply with exactly: OK"'

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
  ^ssh -t $NUC_HOST "sudo nix-private-github nixos-rebuild --rollback switch"
}

def "main nuc-generations" [] {
  print "=== NUC System Generations ==="
  ^ssh $NUC_HOST "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"
}

def "main agents-rollout" [dotfiles_msg: string = "chore: bump agents-workspace"] {
  let ctx = (context)
  let workspace = ($env.HOME | path join "src" "personal" "agents-workspace")
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
