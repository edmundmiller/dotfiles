#!/usr/bin/env bash
set -euo pipefail
source_dir=$1
release_command=$2
shift 2
cleanup() {
  status=$?
  trap - EXIT
  set +e
  bash -c "$release_command"
  release_status=$?
  if [ "$status" -ne 0 ]; then
    exit "$status"
  fi
  if [ "$release_status" -ne 0 ]; then
    exit 1
  fi
  exit 0
}
trap cleanup EXIT
cd "$source_dir"
"$@"
