#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  echo "usage: verify-workspace-cleanup.sh <active-directory> <candidate-directory>" >&2
  exit 64
fi

resolve_directory() {
  cd -- "$1" && pwd -P
}

if ! active_directory=$(resolve_directory "$1"); then
  echo "cleanup refused: active directory is inaccessible: $1" >&2
  exit 2
fi

if ! candidate_directory=$(resolve_directory "$2"); then
  echo "cleanup refused: candidate directory is inaccessible: $2" >&2
  exit 2
fi

if [[ "$candidate_directory" == / ]]; then
  echo "cleanup refused: candidate directory is root" >&2
  exit 2
fi

if [[ "$active_directory" == "$candidate_directory" || "$active_directory" == "$candidate_directory"/* ]]; then
  echo "cleanup deferred: $candidate_directory contains the active agent directory $active_directory" >&2
  exit 1
fi

printf 'cleanup safe: active=%s candidate=%s\n' "$active_directory" "$candidate_directory"
