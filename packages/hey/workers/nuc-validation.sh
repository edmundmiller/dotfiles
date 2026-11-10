#!/usr/bin/env bash
set -uo pipefail

source_dir=$1
content_digest=$2
report_dir=$3
meminfo=$4
minimum_kib=$5
nix_config=$6
lock_file=$7
shift 7
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

[[ "$minimum_kib" =~ ^[0-9]+$ ]] && [ "${#minimum_kib}" -le 10 ] \
  || fail_setup "invalid memory limit"
[ "$#" -gt 0 ] || fail_setup "empty gate plan"
[[ "$content_digest" =~ ^[0-9a-f]{40}$ ]] || fail_setup "invalid snapshot digest"

# Full Nix evaluations are memory-heavy. Queue them so concurrent agents do not
# multiply that load, then constrain build parallelism without skipping checks.
exec 9>"$lock_file"
flock 9 || fail_setup "validation lock failed"
printf 'running\t%s\t\t\t\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$state" \
  || fail_setup "could not record running state"
export NIX_CONFIG="$nix_config"

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
  local available_kib
  if ! available_kib=$(awk '$1 == "MemAvailable:" { print $2; found=1 } END { if (!found) exit 1 }' "$meminfo") \
      || [[ ! "$available_kib" =~ ^[0-9]+$ ]]; then
    printf 'error: cannot read MemAvailable from %s; refusing to start %s\n' "$meminfo" "$gate" >&2
    return 75
  fi
  printf 'host memory preflight: gate=%s available=%s KiB required=%s KiB\n' \
    "$gate" "$available_kib" "$minimum_kib"
  if (( available_kib < minimum_kib )); then
    printf 'error: required host memory headroom is unavailable; refusing to start %s\n' "$gate" >&2
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
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || fail_setup "invalid gate plan header"
  gate=$1
  count=$2
  [[ "$gate" =~ ^[A-Za-z0-9_-]+$ ]] || fail_setup "invalid gate name"
  shift 2
  [[ "$count" =~ ^[0-9]+$ ]] && [ "$count" -gt 0 ] && [ "$count" -le "$#" ] \
    || fail_setup "invalid gate plan arguments"
  run_gate "$gate" "${@:1:$count}"
  shift "$count"
done

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
