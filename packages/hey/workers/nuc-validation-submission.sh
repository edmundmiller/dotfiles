#!/usr/bin/env bash
set -uo pipefail

source_dir=$1
revision=$2
content_digest=$3
report_dir=$4
unit=$5
service_encoded=$6
release_command=$7
evaluator_memory_boundary=$8
state="$report_dir/state.tsv"

submission_setup_failed() {
  local detail=$1
  mkdir -p "$report_dir" 2>/dev/null || true
  printf 'state\ttimestamp\tstatus\toutcome\tdetail\nfailed\t%s\t1\tsubmission\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$detail" > "$state" 2>/dev/null || true
  bash -c "$release_command"
  exit 1
}

mkdir -p "$report_dir" || submission_setup_failed "could not create validation report directory"
printf 'gate\tstatus\tlog_status\tlog\n' > "$report_dir/summary.tsv" \
  || submission_setup_failed "could not initialize validation summary"
printf 'revision=%s\ncontent_digest=git-tree:%s\nsource=%s\nunit=%s\nsubmitted_at=%s\nevaluator_memory_boundary=%s\nbuilder_memory_boundary=%s\n' \
  "$revision" "$content_digest" "$source_dir" "$unit" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$evaluator_memory_boundary" \
  'none: system nix-daemon builders and KVM guests run outside the user service cgroup' \
  > "$report_dir/provenance.txt" \
  || submission_setup_failed "could not write validation provenance"
printf '%s\n' "$unit" > "$report_dir/unit.txt" \
  || submission_setup_failed "could not persist validation unit"
printf 'state\ttimestamp\tstatus\toutcome\tdetail\nqueued\t%s\t\t\t\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$state" \
  || submission_setup_failed "could not initialize validation state"
printf 'systemd-user-unit=%s\n' "$unit" > "$source_dir/.nuc-deploy-active" \
  || submission_setup_failed "could not claim validation snapshot lease"

set +e
printf '%s' "$service_encoded" | base64 --decode | bash
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
bash -c "$release_command"
cleanup_status=$?
if [ "$cleanup_status" -ne 0 ]; then
  outcome=submission+cleanup
  detail="$detail; snapshot release or pruning failed"
fi
printf 'failed\t%s\t1\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$outcome" "$detail" >> "$state"
exit 1
