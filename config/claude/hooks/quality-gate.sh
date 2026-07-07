#!/usr/bin/env bash
# PostToolUse quality gate (Claude Code + Codex): lint edited files.
# Silent + exit 0 on success. Lint failures reported as non-blocking
# additionalContext JSON (exit 2 would hard-block; we don't want that).
set -u

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)

json() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

# Claude Edit/Write/MultiEdit: tool_input.file_path
files=$(json '.tool_input.file_path // empty')
if [ -z "$files" ]; then
  # Codex apply_patch (direct tool or embedded in shell): recover paths
  # from patch markers anywhere in tool_input strings.
  cwd=$(json '.cwd // empty')
  files=$(json '.tool_input? | .. | strings?' |
    sed -nE 's/^\*\*\* (Add|Update) File: (.+)$/\2/p' | sort -u | head -5 |
    while IFS= read -r p; do
      case "$p" in
      /*) printf '%s\n' "$p" ;;
      *) printf '%s\n' "${cwd:-.}/$p" ;;
      esac
    done)
fi
[ -n "$files" ] || exit 0

msgs=""
add_msg() {
  msgs="${msgs}quality-gate: $1 failed for $2
$3
"
}

while IFS= read -r file; do
  [ -n "$file" ] && [ -f "$file" ] || continue
  repo=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$repo" ] &&
    { [ -f "$repo/.pre-commit-config.yaml" ] || [ -f "$repo/.pre-commit-config.yml" ]; } &&
    command -v prek >/dev/null 2>&1; then
    if ! out=$(cd "$repo" && prek run --files "$file" 2>&1); then
      # Fixer hooks rewrite the file on disk; that's not a failure to chase.
      # Re-run once: fixers now pass, only genuine failures remain.
      if printf '%s' "$out" | grep -q 'files were modified by this hook'; then
        msgs="${msgs}quality-gate: $file was auto-formatted on disk by prek — re-read it before further edits.
"
        out=$(cd "$repo" && prek run --files "$file" 2>&1) && out=""
      fi
      if [ -n "$out" ]; then
        msgs="${msgs}quality-gate: prek reported failures after editing $file (may be pre-existing or repo-wide):
$(printf '%s' "$out" | head -c 2000)
"
      fi
    fi
  else
    case "$file" in
    *.py)
      if command -v ruff >/dev/null 2>&1; then
        out=$(ruff check "$file" 2>&1) ||
          add_msg ruff "$file" "$(printf '%s' "$out" | head -c 2000)"
      fi
      ;;
      # *.ts/*.tsx/*.js: eslint intentionally skipped, too slow per-edit
    esac
  fi
done <<EOF
$files
EOF

if [ -n "$msgs" ]; then
  jq -n --arg ctx "$msgs" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
fi
exit 0
