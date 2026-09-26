use ./common.nu *

const NUC_HOST = "nuc"
const UNAS_HOST = "192.168.1.101"
const NUC_WORKTREE_MODES = ["dry-activate" "test" "switch" "build" "vm" "validate"]

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
  let dirty = ($worktree_status.stdout | str trim | is-not-empty)
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
  '
  if $local {
    ^bash -lc $script
  } else {
    ^ssh $NUC_HOST $script
  }
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

  if $mode in $NUC_WORKTREE_MODES {
    print $"=== NUC deploy mode: worktree ($mode) from ($local_hostname) (($local_system)) ==="
    main nuc-worktree $mode
    return
  }

  if $mode != "auto" {
    print -e "error: hey nuc mode must be one of: auto, local, wt, worktree, dry-activate, test, switch, build, vm, validate"
    error make {msg: "invalid hey nuc mode"}
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
  if not ($mode in $NUC_WORKTREE_MODES) {
    print -e $"error: mode must be one of: ($NUC_WORKTREE_MODES | str join ', ')"
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

def nuc-worktree-archive [source: string, revision: string] {
  let parsed = ($revision | parse -r '^(?<revision>[0-9a-f]{40})$')
  if ($parsed | is-empty) {
    error make {msg: "clean NUC snapshots require an exact 40-character lowercase Git revision"}
  }
  ^git -C $source archive --format=tar $revision
}

def nuc-worktree-capture-dirty-tree [source: string, revision: string, index: string] {
  with-env {GIT_INDEX_FILE: $index} {
    ^git -C $source read-tree $revision
    ^git -C $source add -A -- .
    ^git -C $source write-tree | str trim
  }
}

def nuc-worktree-sync [source: string, destination: string, revision: string, dirty: bool, host: string = ""] {
  let index = (^mktemp | str trim)
  rm $index
  let content_digest = try {
    let tree = if $dirty {
      nuc-worktree-capture-dirty-tree $source $revision $index
    } else {
      ^git -C $source rev-parse $"($revision)^{tree}" | str trim
    }
    let archive_revision = if $dirty { $tree } else { $revision }
    if ($host | is-empty) {
      nuc-worktree-archive $source $archive_revision | ^tar --exclude=.nuc-deploy-active -xf - -C $destination
    } else {
      nuc-worktree-archive $source $archive_revision | ^ssh $host $"tar --exclude=.nuc-deploy-active -xf - -C '($destination)'"
    }
    if $dirty {
      let source_after_transfer = (nuc-worktree-capture-dirty-tree $source $revision $index)
      if $source_after_transfer != $tree {
        error make {msg: "NUC snapshot source changed while it was being transferred; retry from a stable worktree"}
      }
    }
    $tree
  } catch {|err|
    rm -f $index
    error make $err
  }
  rm -f $index
  $content_digest
}

def nuc-worktree-prune [script: string, user: string, host: string = $NUC_HOST] {
  if ($host | is-empty) {
    open --raw $script | ^bash -s -- /tmp $user 4
  } else {
    open --raw $script | ^ssh $host $"bash -s -- /tmp '($user)' 4"
  }
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

def nuc-worktree-validation-report-dir [user: string, revision: string] {
  $"/tmp/dotfiles-validation-($user)-($revision)-((random uuid))"
}

def nuc-worktree-validation-command [destination: string, content_digest: string, report_dir: string, meminfo: string = "/proc/meminfo"] {
  let script = r#'
set -uo pipefail

source_dir=$1
content_digest=$2
report_dir=$3
meminfo=$4
summary="$report_dir/summary.tsv"
state="$report_dir/state.tsv"
result="$report_dir/result.tsv"

record_result() {
  local outcome=$1
  local status=$2
  local detail=$3
  local temporary="$result.tmp.$$"
  printf 'outcome\tstatus\tdetail\n%s\t%s\t%s\n' "$outcome" "$status" "$detail" > "$temporary" \
    && mv -f "$temporary" "$result"
}

fail_setup() {
  local detail=$1
  printf 'validation setup failed: %s\n' "$detail" >&2
  record_result setup 1 "$detail" || true
  exit 1
}

# Full Nix evaluations are memory-heavy. Queue them so concurrent agents do not
# multiply that load, then constrain build parallelism without skipping checks.
exec 9>/tmp/dotfiles-nuc-validation.lock
flock 9 || fail_setup "validation lock failed"
printf 'running\t%s\t\t\t\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$state" \
  || fail_setup "could not record running state"
export NIX_CONFIG="max-jobs = 1
cores = 2"

# Synced deployment snapshots deliberately omit the source checkout's .git.
# Give validation an isolated repository without transferring history or credentials.
git -C "$source_dir" init --quiet --initial-branch validation \
  || fail_setup "git init failed"
git -C "$source_dir" config core.hooksPath /dev/null \
  || fail_setup "could not disable synthetic repository hooks"
git -C "$source_dir" -c user.name='NUC Validation' -c user.email='nuc-validation@localhost' \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null add --force --all -- . \
  ':(exclude).nuc-deploy-active' ':(exclude).nuc-deploy-source-revision' \
  || fail_setup "git add failed"
reconstructed_digest=$(git -C "$source_dir" write-tree) \
  || fail_setup "could not reconstruct validation snapshot digest"
if [ "$reconstructed_digest" != "$content_digest" ]; then
  fail_setup "snapshot digest mismatch: expected $content_digest, reconstructed $reconstructed_digest"
fi
git -C "$source_dir" -c user.name='NUC Validation' -c user.email='nuc-validation@localhost' \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet -m "NUC validation snapshot" \
  || fail_setup "git commit failed"
git -C "$source_dir" update-ref refs/remotes/origin/main HEAD \
  || fail_setup "git update-ref failed"

overall=0
logging_failed=0
check_host_headroom() {
  local gate=$1
  local minimum_kib=$((16 * 1024 * 1024))
  local available_kib
  if ! available_kib=$(awk '$1 == "MemAvailable:" { print $2; found=1 } END { if (!found) exit 1 }' "$meminfo") \
      || [[ ! "$available_kib" =~ ^[0-9]+$ ]]; then
    printf 'error: cannot read MemAvailable from %s; refusing to start %s\n' "$meminfo" "$gate" >&2
    return 75
  fi
  printf 'host memory preflight: gate=%s available=%s KiB required=%s KiB\n' \
    "$gate" "$available_kib" "$minimum_kib"
  if (( available_kib < minimum_kib )); then
    printf 'error: less than 16 GiB is available; refusing to start %s\n' "$gate" >&2
    return 75
  fi
}

run_gate() {
  local gate=$1
  shift
  local log="$report_dir/$gate.log"
  printf '\n=== %s ===\n' "$gate"
  printf 'command:'
  printf ' %q' "$@"
  printf '\nlog=%s\n' "$log"
  set +e
  check_host_headroom "$gate" 2>&1 | tee "$log"
  local preflight_status=("${PIPESTATUS[@]}")
  local gate_status=${preflight_status[0]}
  local log_status=${preflight_status[1]}
  if [ "$gate_status" -eq 0 ]; then
    "$@" 2>&1 | tee -a "$log"
    local gate_pipeline_status=("${PIPESTATUS[@]}")
    gate_status=${gate_pipeline_status[0]}
    if [ "${gate_pipeline_status[1]}" -ne 0 ]; then
      log_status=${gate_pipeline_status[1]}
    fi
  else
    printf 'gate not started because its host memory preflight failed\n' | tee -a "$log"
    local refusal_status=("${PIPESTATUS[@]}")
    if [ "${refusal_status[1]}" -ne 0 ]; then
      log_status=${refusal_status[1]}
    fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$gate" "$gate_status" "$log_status" "$log" >> "$summary" || log_status=1
  if [ "$gate_status" -ne 0 ]; then
    overall=1
  fi
  if [ "$log_status" -ne 0 ]; then
    logging_failed=1
  fi
}

cd "$source_dir"
run_gate full python3 scripts/validation.py --full
run_gate nixos python3 scripts/validation.py --platform nixos
run_gate flake-check nix flake check --keep-going -L

printf '\n=== NUC validation summary ===\n'
cat "$summary" || logging_failed=1
printf 'NUC_VALIDATION_REPORT_DIR=%s\n' "$report_dir"
if [ "$logging_failed" -ne 0 ]; then
  record_result logging 1 "one or more gate logs or summary writes failed" || true
  exit 1
fi
if [ "$overall" -ne 0 ]; then
  record_result gates 1 "one or more validation gates failed" || true
  exit 1
fi
record_result success 0 "all validation gates passed" || exit 1
exit 0
'#
  let encoded = ($script | encode base64)
  $"printf '%s' '($encoded)' | base64 --decode | bash -s -- '($destination)' '($content_digest)' '($report_dir)' '($meminfo)'"
}

def nuc-worktree-validation-finalizer-command [destination: string, user: string, report_dir: string, root: string = "/tmp"] {
  let release = (nuc-worktree-release-script $destination $user $root)
  let script = r#'
set +e

report_dir=$1
result="$report_dir/result.tsv"
state="$report_dir/state.tsv"
outcome=interrupted
status=1
detail="service ended without a validation result (${SERVICE_RESULT:-unknown}/${EXIT_CODE:-unknown}/${EXIT_STATUS:-unknown})"

if [ -f "$result" ]; then
  IFS=$'\t' read -r outcome status detail < <(tail -n 1 "$result")
elif [ "${SERVICE_RESULT:-}" = "success" ]; then
  outcome=setup
  detail="validation exited without recording a result"
fi

__RELEASE__
cleanup_status=$?
if [ "$cleanup_status" -ne 0 ]; then
  if [ "$outcome" = success ]; then
    outcome=cleanup
    detail="snapshot release or pruning failed"
  else
    outcome="${outcome}+cleanup"
    detail="$detail; snapshot release or pruning failed"
  fi
  status=1
fi

if [ "${SERVICE_RESULT:-success}" != success ] && [ "$status" -eq 0 ]; then
  outcome=interrupted
  status=1
  detail="service ended with ${SERVICE_RESULT:-unknown}/${EXIT_CODE:-unknown}/${EXIT_STATUS:-unknown}"
fi

terminal_state=failed
if [ "$status" -eq 0 ]; then
  terminal_state=completed
fi
printf '%s\t%s\t%s\t%s\t%s\n' \
  "$terminal_state" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$outcome" "$detail" >> "$state"
exit "$status"
'#
  let finalizer = ($script | str replace "__RELEASE__" $release)
  let encoded = ($finalizer | encode base64)
  $"printf '%s' '($encoded)' | base64 --decode | bash -s -- '($report_dir)'"
}

def nuc-worktree-validation-service-command [command: string, finalizer: string, unit: string] {
  let parsed = ($unit | parse -r '^nuc-validation-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.service$')
  if ($parsed | is-empty) {
    error make {msg: "NUC validation unit must be a generated nuc-validation UUID service"}
  }
  let encoded = ($command | encode base64)
  let finalizer_encoded = ($finalizer | encode base64)
  let template = r#'uid=$(id -u); export XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus; systemd-run --user --wait --collect --quiet --unit='__UNIT__' --setenv="PATH=$PATH" --setenv="HOME=$HOME" --setenv="USER=${USER:-user}" --property=MemoryHigh=10G --property=MemoryMax=12G --property=OOMPolicy=continue --property="ExecStopPost=/bin/sh -c \"echo '__FINALIZER__' | base64 --decode | bash\"" bash -c "echo '__COMMAND__' | base64 --decode | bash"'#
  $template | str replace "__UNIT__" $unit | str replace "__FINALIZER__" $finalizer_encoded | str replace "__COMMAND__" $encoded
}

def nuc-worktree-validation-unit [destination: string] {
  let name = ($destination | path basename)
  let parsed = ($name | parse -r '^dotfiles-worktree-[A-Za-z0-9._-]+-[0-9a-f]{40}-(clean|dirty)-(?<snapshot_id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$')
  if ($parsed | is-empty) {
    error make {msg: "NUC validation snapshot must have a generated deploy snapshot name"}
  }
  $"nuc-validation-($parsed.0.snapshot_id).service"
}

def nuc-worktree-claim-validation-lease [destination: string, unit: string, host: string = ""] {
  let expected_unit = (nuc-worktree-validation-unit $destination)
  if $unit != $expected_unit {
    error make {msg: "NUC validation unit must match its deploy snapshot UUID"}
  }
  let lease = ($"systemd-user-unit=($unit)\n" | encode base64)
  let command = $"printf '%s' '($lease)' | base64 --decode > '($destination)/.nuc-deploy-active'"
  if ($host | is-empty) {
    ^bash -c $command
  } else {
    ^ssh $host $command
  }
}

def nuc-worktree-validation-submission-command [destination: string, revision: string, content_digest: string, report_dir: string, unit: string, user: string, service_command: string, root: string = "/tmp"] {
  let release = (nuc-worktree-release-script $destination $user $root)
  let service_encoded = ($service_command | encode base64)
  let script = r#'
set -uo pipefail

source_dir=$1
revision=$2
content_digest=$3
report_dir=$4
unit=$5
state="$report_dir/state.tsv"

submission_setup_failed() {
  local detail=$1
  mkdir -p "$report_dir" 2>/dev/null || true
  printf 'state\ttimestamp\tstatus\toutcome\tdetail\nfailed\t%s\t1\tsubmission\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$detail" > "$state" 2>/dev/null || true
  __RELEASE__
  exit 1
}

mkdir -p "$report_dir" || submission_setup_failed "could not create validation report directory"
printf 'gate\tstatus\tlog_status\tlog\n' > "$report_dir/summary.tsv" \
  || submission_setup_failed "could not initialize validation summary"
printf 'revision=%s\ncontent_digest=git-tree:%s\nsource=%s\nunit=%s\nsubmitted_at=%s\nevaluator_memory_boundary=%s\nbuilder_memory_boundary=%s\n' \
  "$revision" "$content_digest" "$source_dir" "$unit" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  'user service: MemoryHigh=10G MemoryMax=12G' \
  'none: system nix-daemon builders and KVM guests run outside the user service cgroup' \
  > "$report_dir/provenance.txt" \
  || submission_setup_failed "could not write validation provenance"
printf '%s\n' "$unit" > "$report_dir/unit.txt" \
  || submission_setup_failed "could not persist validation unit"
printf 'state\ttimestamp\tstatus\toutcome\tdetail\nqueued\t%s\t\t\t\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$state" \
  || submission_setup_failed "could not initialize validation state"

set +e
printf '%s' '__SERVICE__' | base64 --decode | bash
service_status=$?
set -e
if [ "$service_status" -eq 0 ]; then
  exit 0
fi

# A terminal row proves the service started and its finalizer owns cleanup.
if tail -n 1 "$state" | cut -f1 | grep -Eq '^(completed|failed)$'; then
  exit "$service_status"
fi

# Only release after the manager positively reports that no unit was created.
uid=$(id -u)
export XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus
set +e
load_state=$(systemctl --user show "$unit" --property=LoadState --value 2>/dev/null)
show_status=$?
set -e
if [ "$show_status" -ne 0 ] || [ "$load_state" != not-found ]; then
  printf 'warning: validation submission status is uncertain; preserving lease for unit %s\n' "$unit" >&2
  exit "$service_status"
fi

outcome=submission
detail="transient service submission was rejected"
__RELEASE__
cleanup_status=$?
if [ "$cleanup_status" -ne 0 ]; then
  outcome=submission+cleanup
  detail="$detail; snapshot release or pruning failed"
fi
printf 'failed\t%s\t1\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$outcome" "$detail" >> "$state"
exit 1
'#
  let submission = ($script | str replace "__SERVICE__" $service_encoded | str replace --all "__RELEASE__" $release)
  let encoded = ($submission | encode base64)
  $"printf '%s' '($encoded)' | base64 --decode | bash -s -- '($destination)' '($revision)' '($content_digest)' '($report_dir)' '($unit)'"
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
    let content_digest = (nuc-worktree-sync $source $destination $revision $dirty $host)
    let command = (nuc-worktree-revision-command $destination $revision)
    if ($host | is-empty) {
      ^bash -c $command
    } else {
      ^ssh $host $command
    }
    $content_digest
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
  let local_validation = ($mode == "validate") and ((^hostname -s | str trim) == $NUC_HOST)
  let target_host = if $local_validation { "" } else { $NUC_HOST }

  let target = if $local_validation { $remote_dir } else { $"($NUC_HOST):($remote_dir)" }
  print $"=== Syncing current worktree to NUC: ($ctx.flake_dir) -> ($target) ==="
  print $"NUC_WORKTREE_REMOTE_DIR=($remote_dir)"
  nuc-worktree-prune $prune_script $deploy_user $target_host
  if $local_validation {
    mkdir $remote_dir
    ^touch ($remote_dir | path join ".nuc-deploy-active")
  } else {
    ^ssh $NUC_HOST $"mkdir -p '($remote_dir)'"
    ^ssh $NUC_HOST $"touch '($remote_dir)/.nuc-deploy-active'"
  }
  let content_digest = (nuc-worktree-prepare $ctx.flake_dir $remote_dir $revision $source.dirty $deploy_user $target_host)

  if $mode == "validate" {
    let report_dir = (nuc-worktree-validation-report-dir $deploy_user $revision)
    let unit = (nuc-worktree-validation-unit $remote_dir)
    print "=== Queueing full, NixOS/KVM, and flake gates from synced worktree on NUC ==="
    print $"NUC_VALIDATION_REPORT_DIR=($report_dir)"
    print $"NUC_VALIDATION_UNIT=($unit)"
    nuc-worktree-claim-validation-lease $remote_dir $unit $target_host
    let command = (nuc-worktree-validation-command $remote_dir $content_digest $report_dir)
    let finalizer = (nuc-worktree-validation-finalizer-command $remote_dir $deploy_user $report_dir)
    let service_command = (nuc-worktree-validation-service-command $command $finalizer $unit)
    let submission_command = (nuc-worktree-validation-submission-command $remote_dir $revision $content_digest $report_dir $unit $deploy_user $service_command)
    if $local_validation {
      ^bash -c $submission_command
    } else {
      ^ssh $NUC_HOST $submission_command
    }
    return
  }

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

def agents-rollout-deploy-mode [mode: string] {
  let allowed = ["none" "build" "dry-activate" "test" "switch"]
  if not ($mode in $allowed) {
    print -e $"error: agents rollout deploy mode must be one of: ($allowed | str join ', ')"
    error make {msg: "invalid agents rollout deploy mode"}
  }
  $mode
}

def pin-agents-workspace-input [flake_path: string, revision: string] {
  let parsed_revision = ($revision | parse -r '^(?<revision>[0-9a-f]{40})$')
  if ($parsed_revision | is-empty) {
    error make {msg: "agents-workspace pin requires an exact 40-character lowercase Git revision"}
  }

  let source = (open --raw $flake_path)
  let pins = ($source | parse -r 'github:edmundmiller/agents-workspace/(?<revision>[0-9a-f]{40})')
  if ($pins | length) != 1 {
    error make {msg: "expected exactly one pinned agents-workspace input in flake.nix"}
  }

  let current_revision = ($pins | get 0.revision)
  $source
    | str replace $"github:edmundmiller/agents-workspace/($current_revision)" $"github:edmundmiller/agents-workspace/($revision)"
    | save --force $flake_path
}

def require-clean-rollout-repository [repository: string, label: string] {
  let status = (^git -C $repository status --porcelain=v1 --untracked-files=normal | complete)
  if $status.exit_code != 0 {
    error make {msg: $"could not inspect ($label) repository"}
  }
  if not ($status.stdout | str trim | is-empty) {
    error make {msg: $"($label) repository is dirty; commit or stash it first"}
  }
}

def "main agents-rollout" [
  dotfiles_msg: string = "chore: bump agents-workspace"
  --workspace: string = ""
  --deploy-mode: string = "switch"
] {
  let ctx = (context)
  let workspace = if ($workspace | is-empty) {
    $env.HOME | path join "src" "personal" "agents-workspace"
  } else {
    $workspace | path expand
  }
  let dotfiles = $ctx.flake_dir
  let validated_deploy_mode = (agents-rollout-deploy-mode $deploy_mode)

  require-clean-rollout-repository $workspace "agents-workspace"
  require-clean-rollout-repository $dotfiles "dotfiles"

  if $validated_deploy_mode != "none" {
    print "=== Verify NUC tailnet target ==="
    ^ssh $NUC_HOST 'set -eu; hostname="$(hostname)"; uname="$(uname -a)"; printf "hostname=%s\nuname=%s\n" "$hostname" "$uname"; test "$hostname" = "nuc"'
  }

  print "=== Push agents-workspace ==="
  cd $workspace
  ^git pull --rebase
  ^git push
  let workspace_revision = (^git rev-parse HEAD | str trim)

  print "=== Pin agents-workspace input ==="
  cd $dotfiles
  pin-agents-workspace-input ($dotfiles | path join "flake.nix") $workspace_revision
  let authenticated_nix_config = (github-nix-config)
  with-env { NIX_CONFIG: $authenticated_nix_config } {
    ^nix flake update agents-workspace
  }

  print "=== Commit + push dotfiles ==="
  let pin_changed = (^git diff --quiet -- flake.nix flake.lock | complete)
  if $pin_changed.exit_code == 0 {
    print "agents-workspace pin unchanged; skipping commit"
  } else {
    ^git add flake.nix flake.lock
    ^git commit -m $dotfiles_msg
  }
  ^git pull --rebase
  ^git push

  if $validated_deploy_mode == "none" {
    print "=== NUC deployment skipped (--deploy-mode none) ==="
    return
  }

  print "=== Build pinned dotfiles + agents-workspace on NUC ==="
  main nuc build

  if $validated_deploy_mode == "build" {
    print "=== NUC activation skipped (--deploy-mode build) ==="
    return
  }

  print $"=== Activate NUC with mode: ($validated_deploy_mode) ==="
  main nuc $validated_deploy_mode
}
