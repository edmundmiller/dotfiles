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
fake_openwiki="$test_root/openwiki"
invocation="$test_root/invocation"

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
git -C "$repo" config user.name "OpenWiki recovery test"
git -C "$repo" config user.email "openwiki-recovery-test@example.invalid"
git -C "$repo" switch -c automation/openwiki >/dev/null
printf '%s\n' "interrupted synthesis" >> "$repo/README.md"
printf '%s\n' "temporary plan" > "$repo/_plan.md"

cat > "$fake_openwiki" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$invocation"
EOF
chmod +x "$fake_openwiki"

HOME="$test_root/home" \
OPENWIKI_SCHEDULE_REPO="$repo" \
OPENWIKI_SCHEDULE_REMOTE="$remote" \
OPENWIKI_SCHEDULE_EXECUTABLE="$fake_openwiki" \
  "$scheduled_ingestion"

test "$(cat "$invocation")" = "ingest all --scheduled --print"
test -z "$(git -C "$repo" status --porcelain=v1)"
test "$(git -C "$repo" branch --show-current)" = "automation/openwiki"

recovery_branch="$(git -C "$repo" for-each-ref \
  --format='%(refname:short)' 'refs/heads/automation/openwiki-recovery-*')"
test -n "$recovery_branch"
test "$(git -C "$repo" show "$recovery_branch:README.md" | tail -n 1)" = \
  "interrupted synthesis"
test "$(git -C "$repo" show "$recovery_branch:_plan.md")" = "temporary plan"
