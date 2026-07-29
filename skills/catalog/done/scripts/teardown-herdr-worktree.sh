#!/usr/bin/env bash
set -euo pipefail

defer() {
  printf 'cleanup deferred: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  defer "usage: teardown-herdr-worktree.sh <recorded-task-root>"
fi

if [[ "${HERDR_ENV:-}" != 1 ]]; then
  defer "HERDR_ENV=1 is required"
fi

workspace_id="${HERDR_WORKSPACE_ID:-}"
if [[ -z "$workspace_id" ]]; then
  defer "HERDR_WORKSPACE_ID is required"
fi

candidate_input=$1
if [[ ! -d "$candidate_input" ]]; then
  defer "recorded task root is inaccessible"
fi
candidate=$(cd -- "$candidate_input" && pwd -P)
active_directory=$(pwd -P)

case "$active_directory" in
  "$candidate" | "$candidate"/*) ;;
  *) defer "active directory is outside the recorded task root" ;;
esac

if ! repo_root=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null); then
  defer "recorded task root is not a Git worktree"
fi
repo_root=$(cd -- "$repo_root" && pwd -P)
if [[ "$repo_root" != "$candidate" ]]; then
  defer "recorded task root is not the Git worktree root"
fi

if [[ -n "$(git -C "$candidate" status --porcelain=v1 --untracked-files=all)" ]]; then
  defer "recorded task worktree is not clean"
fi

herdr_bin="${HERDR_BIN_PATH:-herdr}"
if [[ "$herdr_bin" == */* ]]; then
  [[ -x "$herdr_bin" ]] || defer "Herdr executable is unavailable"
elif ! herdr_bin=$(command -v "$herdr_bin"); then
  defer "Herdr executable is unavailable"
fi
command -v python3 >/dev/null 2>&1 || defer "python3 is unavailable"

if ! worktree_json=$(
  "$herdr_bin" worktree list --workspace "$workspace_id" --json 2>/dev/null
); then
  defer "Herdr worktree provenance query failed"
fi

if ! provenance_error=$(
  python3 -c '
import json
import os
import sys

workspace_id, candidate = sys.argv[1:]

def reject(message):
    print(message)
    raise SystemExit(1)

try:
    payload = json.load(sys.stdin)
except (json.JSONDecodeError, UnicodeDecodeError):
    reject("Herdr returned invalid worktree JSON")

result = payload.get("result") if isinstance(payload, dict) else None
if not isinstance(result, dict) or result.get("type") != "worktree_list":
    reject("Herdr response was not a worktree list")

worktrees = result.get("worktrees")
if not isinstance(worktrees, list):
    reject("Herdr response omitted worktree provenance")

matches = [
    entry
    for entry in worktrees
    if isinstance(entry, dict)
    and isinstance(entry.get("path"), str)
    and os.path.realpath(entry["path"]) == candidate
    and entry.get("open_workspace_id") == workspace_id
    and entry.get("is_linked_worktree") is True
    and entry.get("is_prunable") is False
]
if len(matches) != 1:
    reject("Herdr workspace does not own the recorded task worktree")
' "$workspace_id" "$candidate" <<<"$worktree_json" 2>&1
); then
  defer "$provenance_error"
fi

exec "$herdr_bin" worktree remove --workspace "$workspace_id" --json
