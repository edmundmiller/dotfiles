#!/usr/bin/env bats

setup() {
  root_dir=$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)
  script="$root_dir/bin/bd-find-all"
}

@test "format cleans title and stays single-line" {
  json='[{"repo_name":"dotfiles","id":"dotfiles-k46","title":"line1\nline2\tstuff","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]
  [ -n "$output" ]

  display=$(printf '%s' "$output" | awk -F'\t' '{print $8}')

  [[ "$display" == *"line1 line2 stuff"* ]]
  [[ "$display" == *"│"* ]]
  [[ "$display" == *"k46"* ]]

  line_count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 1 ]
}
