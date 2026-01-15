#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$root_dir/bin/bd-find-all"

json='[{"repo_name":"dotfiles","id":"dotfiles-k46","title":"line1\nline2\tstuff","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'
output=$(printf '%s' "$json" | "$script" --format-only)

if [[ -z "$output" ]]; then
    echo "expected formatted output"
    exit 1
fi

display=$(printf '%s' "$output" | awk -F'\t' '{print $8}')

if [[ "$display" != *"line1 line2 stuff"* ]]; then
    echo "expected title cleanup"
    exit 1
fi

if [[ "$display" != *"│"* ]]; then
    echo "expected separator in display"
    exit 1
fi

if [[ "$display" != *"k46"* ]]; then
    echo "expected hash in display"
    exit 1
fi

line_count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
if [[ "$line_count" -ne 1 ]]; then
    echo "expected single output line"
    exit 1
fi

echo "ok"
