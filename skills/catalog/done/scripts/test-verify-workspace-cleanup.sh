#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
verifier="$script_dir/verify-workspace-cleanup.sh"

expected_failure=1
if (( expected_failure )); then
  if [[ -x "$verifier" ]]; then
    echo "unexpected pass: active-worktree cleanup guard is already implemented" >&2
    exit 1
  fi
  echo "expected failure: active-worktree cleanup guard is not implemented"
  exit 0
fi
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

active="$tmpdir/active/worktree/subdirectory"
unsafe_candidate="$tmpdir/active/worktree"
safe_candidate="$tmpdir/safe-worktree"
mkdir -p "$active" "$safe_candidate"

if output=$("$verifier" "$active" "$unsafe_candidate" 2>&1); then
  echo "expected active worktree cleanup to be deferred" >&2
  exit 1
fi
[[ "$output" == *"cleanup deferred"* ]]

output=$("$verifier" "$active" "$safe_candidate")
[[ "$output" == *"cleanup safe"* ]]

if output=$("$verifier" "$tmpdir/missing" "$safe_candidate" 2>&1); then
  echo "expected inaccessible active directory to be refused" >&2
  exit 1
fi
[[ "$output" == *"active directory is inaccessible"* ]]

repo="$tmpdir/repo"
git init -q -b main "$repo"
git -C "$repo" config user.email "done-test@example.invalid"
git -C "$repo" config user.name "Done test"
printf 'seed\n' >"$repo/seed"
git -C "$repo" add seed
git -C "$repo" commit -qm seed

for launcher in codex herdr; do
  worktree="$tmpdir/$launcher/worktrees/dotfiles/task"
  mkdir -p "$(dirname "$worktree")"
  git -C "$repo" worktree add -qb "${launcher}-task" "$worktree"

  active_path=$(cd "$worktree" && pwd -P)
  (
    cd "$worktree"
    if "$verifier" "$active_path" "$worktree"; then
      git -C "$repo" worktree remove "$worktree"
    fi
    [[ "$(pwd -P)" == "$active_path" ]]
  )
  [[ -d "$worktree" ]]
done

git -C "$repo" worktree add -qb safe "$safe_candidate"
"$verifier" "$tmpdir/codex/worktrees/dotfiles/task" "$safe_candidate"
git -C "$repo" worktree remove "$safe_candidate"
[[ ! -e "$safe_candidate" ]]
