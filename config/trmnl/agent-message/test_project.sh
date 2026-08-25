#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src_dir="$project_dir/src"

required_files=(
  "$project_dir/.trmnlp.yml"
  "$src_dir/full.liquid"
  "$src_dir/half_horizontal.liquid"
  "$src_dir/half_vertical.liquid"
  "$src_dir/quadrant.liquid"
  "$src_dir/shared.liquid"
  "$src_dir/settings.yml"
  "$project_dir/bin/trmnlp"
)

for required_file in "${required_files[@]}"; do
  test -f "$required_file" || {
    printf 'missing required TRMNLP file: %s\n' "$required_file" >&2
    exit 1
  }
done

grep -q '^framework_version: 3\.2\.0$' "$src_dir/settings.yml"
grep -q '^id: __UNASSIGNED__$' "$src_dir/settings.yml"
test -x "$project_dir/bin/trmnlp"

for variable in headline message source status timestamp progress; do
  rg -q "(^|[[:space:]{])$variable([[:space:]}|])" "$src_dir"/*.liquid || {
    printf 'missing template variable: %s\n' "$variable" >&2
    exit 1
  }
done

rg -q 'progress-bar' "$src_dir"/*.liquid
rg -q 'progress[[:space:]]*\| plus: 0[[:space:]]*\| at_least: 0[[:space:]]*\| at_most: 100' "$src_dir/shared.liquid"
rg -q 'layout--stretch-x' "$src_dir"/*.liquid
rg -q 'lg:' "$src_dir"/*.liquid
rg -q 'portrait:' "$src_dir"/*.liquid
! rg -n 'Monica|Edmund|Aviato|busy' "$project_dir" --glob '*.liquid' --glob '*.yml'

printf 'TRMNLP agent-message structural checks passed\n'
