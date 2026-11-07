#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: test-scheduled-ingestion-recovery.sh /path/to/openwiki-scheduled-ingestion" >&2
  exit 64
fi
scheduled_ingestion="$1"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

setup_case() {
  case_root="$test_root/$1"
  mkdir -p "$case_root"
  remote="$case_root/remote.git"
  repo="$case_root/repo"
  invocation="$case_root/invocation"
  fake_openwiki="$case_root/openwiki"
  git init --bare --initial-branch=main "$remote" >/dev/null
  git init --initial-branch=main "$repo" >/dev/null
  git -C "$repo" config user.name 'OpenWiki safety test'
  git -C "$repo" config user.email 'openwiki-safety@example.invalid'
  mkdir -p "$repo/04_Resources"
  printf 'baseline\n' > "$repo/04_Resources/note.md"
  git -C "$repo" add .
  git -C "$repo" commit -m baseline >/dev/null
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -u origin main >/dev/null 2>&1
  git -C "$repo" switch -c automation/openwiki >/dev/null 2>&1
  baseline="$(git -C "$repo" rev-parse HEAD)"
  cat > "$fake_openwiki" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$TEST_INVOCATION"
if [ "${TEST_COMMIT:-0}" = 1 ]; then
  target="${TEST_PATH:-04_Resources/note.md}"
  printf 'current run\n' >> "$target"
  git add "$target"
  git commit -m 'docs(openwiki): current run' >/dev/null
fi
if [ "${TEST_DIRTY:-0}" = 1 ]; then
  printf 'unfinished output\n' >> 04_Resources/note.md
fi
exit "${TEST_EXIT:-0}"
SCRIPT
  chmod +x "$fake_openwiki"
}

run_schedule() {
  result=0
  HOME="$case_root/home" \
    OPENWIKI_SCHEDULE_REPO="$repo" \
    OPENWIKI_SCHEDULE_REMOTE="$remote" \
    OPENWIKI_SCHEDULE_EXECUTABLE="$fake_openwiki" \
    TEST_INVOCATION="$invocation" \
    "$scheduled_ingestion" > "$case_root/output" 2>&1 || result=$?
}

assert_remote_unchanged() {
  test "$(git --git-dir="$remote" rev-parse main)" = "$baseline" || {
    echo "FAIL: $case_root published changes that were not authorized successful-run output" >&2
    cat "$case_root/output" >&2
    exit 1
  }
}

setup_case pending-commit
printf 'manual run\n' >> "$repo/04_Resources/note.md"
git -C "$repo" add . && git -C "$repo" commit -m 'unreviewed manual run' >/dev/null
pending="$(git -C "$repo" rev-parse HEAD)"
export OPENWIKI_SCHEDULE_PUBLISH=1 TEST_COMMIT=0 TEST_EXIT=0
run_schedule
assert_remote_unchanged
test "$result" = 75
test ! -e "$invocation"
test "$(git -C "$repo" rev-parse HEAD)" = "$pending"
echo 'PASS: pre-existing commits preserved and never published'

setup_case dirty-worktree
printf 'interrupted synthesis\n' >> "$repo/04_Resources/note.md"
printf 'untracked plan\n' > "$repo/_plan.md"
run_schedule
assert_remote_unchanged
test "$result" = 75
test ! -e "$invocation"
test "$(tail -n 1 "$repo/04_Resources/note.md")" = 'interrupted synthesis'
test "$(cat "$repo/_plan.md")" = 'untracked plan'
test "$(git -C "$repo" rev-parse HEAD)" = "$baseline"
echo 'PASS: dirty files preserved without committing or switching branches'

setup_case failed-ingestion
export TEST_COMMIT=1 TEST_EXIT=7
run_schedule
assert_remote_unchanged
test "$result" = 7
test "$(git -C "$repo" rev-parse HEAD)" != "$baseline"
test "$(cat "$invocation")" = 'ingest all --scheduled --print'
echo 'PASS: failed ingestion retains its local commit without publishing'
export TEST_EXIT=0
run_schedule
assert_remote_unchanged
test "$result" = 75
echo 'PASS: later successful invocation cannot publish prior failed output'

setup_case out-of-scope-output
export TEST_PATH=outside-wiki.md
run_schedule
assert_remote_unchanged
test "$result" = 75
unset TEST_PATH
echo 'PASS: commits outside the wiki are preserved without publication'

setup_case unfinished-output
export TEST_COMMIT=0 TEST_DIRTY=1
run_schedule
assert_remote_unchanged
test "$result" = 75
unset TEST_DIRTY
echo 'PASS: uncommitted output is preserved without publication'

setup_case publish-disabled
unset OPENWIKI_SCHEDULE_PUBLISH
export TEST_COMMIT=0 TEST_EXIT=0
run_schedule
assert_remote_unchanged
test "$result" = 78
test ! -e "$invocation"
echo 'PASS: missing publication opt-in refuses scheduled run'

setup_case successful-ingestion
export OPENWIKI_SCHEDULE_PUBLISH=1 TEST_COMMIT=1 TEST_EXIT=0
run_schedule
test "$result" = 0
test "$(git --git-dir="$remote" rev-parse main)" = "$(git -C "$repo" rev-parse HEAD)"
test "$(git --git-dir="$remote" show main:04_Resources/note.md | tail -n 1)" = 'current run'
echo 'PASS: explicitly authorized successful run publishes only current-run output'

setup_case no-op
export TEST_COMMIT=0 TEST_EXIT=0
run_schedule
test "$result" = 0
assert_remote_unchanged
echo 'PASS: no-op ingestion leaves remote unchanged'
