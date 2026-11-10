#!/usr/bin/env bash
set -uo pipefail
source_dir=$1
user=$2
root=$3
keep=$4
prune_script=$5
status=0
if ! rm -f "$source_dir/.nuc-deploy-active"; then
  printf 'warning: failed to release snapshot lease: %s\n' "$source_dir" >&2
  status=1
fi
if ! bash -c "$prune_script" -- "$root" "$user" "$keep"; then
  printf 'warning: failed to prune completed snapshots after: %s\n' "$source_dir" >&2
  status=1
fi
exit "$status"
