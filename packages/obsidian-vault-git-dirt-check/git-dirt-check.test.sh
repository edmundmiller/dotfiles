#!/usr/bin/env bash
set -euo pipefail

checker="${1:?usage: git-dirt-check.test.sh CHECKER}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/obsidian-vault-git-dirt.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init --quiet
git -C "$fixture" config user.email "test@example.com"
git -C "$fixture" config user.name "Test"
mkdir -p "$fixture/00_Inbox" "$fixture/.beads"
printf 'initial\n' > "$fixture/00_Inbox/human.md"
printf 'initial\n' > "$fixture/.beads/issues.jsonl"
git -C "$fixture" add .
git -C "$fixture" commit --quiet -m "fixture"

printf 'human edit\n' >> "$fixture/00_Inbox/human.md"
"$checker" "$fixture"

printf 'generated churn\n' >> "$fixture/.beads/issues.jsonl"
if "$checker" "$fixture" >"$fixture/check.out" 2>&1; then
  echo "expected dirt outside 00_Inbox to fail" >&2
  exit 1
fi
grep -F '.beads/issues.jsonl' "$fixture/check.out" >/dev/null
if grep -F '00_Inbox/human.md' "$fixture/check.out" >/dev/null; then
  echo "allowed inbox dirt was reported" >&2
  exit 1
fi
