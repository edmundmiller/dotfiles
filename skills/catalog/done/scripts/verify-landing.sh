#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "usage: verify-landing.sh <integration-tip> <default-branch> [remote]" >&2
  exit 64
fi

integration_ref=$1
default_branch=$2
remote=${3:-}

integration_tip=$(git rev-parse --verify "${integration_ref}^{commit}")
local_tip=$(git rev-parse --verify "${default_branch}^{commit}")

if ! git merge-base --is-ancestor "$integration_tip" "$local_tip"; then
  echo "landing incomplete: $integration_tip is not on $default_branch" >&2
  exit 1
fi

if [[ -n "$remote" ]]; then
  remote_tip=$(git ls-remote --exit-code "$remote" "refs/heads/$default_branch" | awk 'NR == 1 { print $1 }')
  if [[ -z "$remote_tip" ]]; then
    echo "landing incomplete: $remote has no $default_branch branch" >&2
    exit 1
  fi
  if [[ "$local_tip" != "$remote_tip" ]]; then
    echo "landing incomplete: local $default_branch ($local_tip) != $remote/$default_branch ($remote_tip)" >&2
    exit 1
  fi
fi

printf 'integration_tip=%s\ndefault_branch=%s\nlocal_tip=%s\n' \
  "$integration_tip" "$default_branch" "$local_tip"
if [[ -n "$remote" ]]; then
  printf 'remote=%s\nremote_tip=%s\n' "$remote" "$remote_tip"
else
  printf 'remote=none\n'
fi
