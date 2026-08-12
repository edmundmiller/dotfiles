#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: test-scheduled-ingestion-recovery.sh /path/to/openwiki-scheduled-ingestion" >&2
  exit 64
fi

scheduled_ingestion="$1"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

remote="$test_root/remote.git"
seed="$test_root/seed"
repo="$test_root/repo"
output="$test_root/output"

git init --bare "$remote" >/dev/null
git init --initial-branch=main "$seed" >/dev/null
git -C "$seed" config user.name "OpenWiki recovery test"
git -C "$seed" config user.email "openwiki-recovery-test@example.invalid"
printf '%s\n' "baseline" > "$seed/README.md"
git -C "$seed" add README.md
git -C "$seed" commit -m "baseline" >/dev/null
git -C "$seed" remote add origin "$remote"
git -C "$seed" push -u origin main >/dev/null
git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

git clone "$remote" "$repo" >/dev/null
git -C "$repo" switch -c automation/openwiki >/dev/null
printf '%s\n' "interrupted synthesis" >> "$repo/README.md"
printf '%s\n' "temporary plan" > "$repo/_plan.md"

set +e
HOME="$test_root/home" \
OPENWIKI_SCHEDULE_REPO="$repo" \
OPENWIKI_SCHEDULE_REMOTE="$remote" \
  "$scheduled_ingestion" >"$output" 2>&1
status=$?
set -e

# Regression witness: the current launcher permanently wedges on dirty state.
test "$status" -eq 75
grep -F "preserved dirty isolated checkout" "$output" >/dev/null
test -n "$(git -C "$repo" status --porcelain=v1)"
