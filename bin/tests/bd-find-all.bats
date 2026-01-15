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

@test "format handles null title" {
  skip "Need bats for run/skip gating first"
  json='[{"repo_name":"dotfiles","id":"dotfiles-k47","title":null,"status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]
  [ -n "$output" ]

  display=$(printf '%s' "$output" | awk -F'\t' '{print $8}')
  [[ "$display" == *"untitled"* ]]
}

@test "format handles missing fields" {
  skip "Need bats for run/skip gating first"
  json='[{"repo_name":"dotfiles","id":"dotfiles-k48","title":"title only","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "format keeps full id in hidden fields" {
  skip "Need bats for run/skip gating first"
  json='[{"repo_name":"dotfiles","id":"dotfiles-k49","title":"title","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]

  full_id=$(printf '%s' "$output" | awk -F'\t' '{print $2}')
  [ "$full_id" = "dotfiles-k49" ]
}

@test "format outputs eight fields" {
  skip "Need bats for run/skip gating first"
  json='[{"repo_name":"dotfiles","id":"dotfiles-k50","title":"title","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]

  field_count=$(printf '%s' "$output" | awk -F'\t' '{print NF}')
  [ "$field_count" -eq 8 ]
}
