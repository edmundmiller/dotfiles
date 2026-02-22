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
  json='[{"repo_name":"dotfiles","id":"dotfiles-k47","title":null,"status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]
  [ -n "$output" ]

  display=$(printf '%s' "$output" | awk -F'\t' '{print $8}')
  [[ "$display" == *"untitled"* ]]

  line_count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 1 ]
}

@test "format cleans carriage returns" {
  json='[{"repo_name":"dotfiles","id":"dotfiles-k47r","title":"line1\rline2","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]
  [ -n "$output" ]

  display=$(printf '%s' "$output" | awk -F'\t' '{print $8}')
  [[ "$display" == *"line1 line2"* ]]
}

@test "format handles missing fields" {
  json='[{"repo_name":"dotfiles","id":"dotfiles-k48","title":"title only","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "format keeps full id in hidden fields" {
  json='[{"repo_name":"dotfiles","id":"dotfiles-k49","title":"title","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]

  full_id=$(printf '%s' "$output" | awk -F'\t' '{print $2}')
  [ "$full_id" = "dotfiles-k49" ]
}

@test "format outputs eight fields" {
  json='[{"repo_name":"dotfiles","id":"dotfiles-k50","title":"title","status":"open","priority":2,"issue_type":"task","repo_path":"/tmp"}]'

  JSON="$json" SCRIPT="$script" run bash -c 'printf "%s" "$JSON" | "$SCRIPT" --format-only'

  [ "$status" -eq 0 ]

  field_count=$(printf '%s' "$output" | awk -F'\t' '{print NF}')
  [ "$field_count" -eq 8 ]
}

# ── Preview rendering (single jq call) ──────────────────────────

# Extract the preview jq filter from the script so we can test it
# without needing `bd show` or a real repo
_run_preview_jq() {
  local json="$1" id="$2" repo="$3"
  echo "$json" | jq -r --arg id "$id" --arg repo "$repo" '
    .[0] // empty |
    def sep: "\u001b[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\u001b[0m";
    def g: "\u001b[90m";
    def b: "\u001b[1m";
    def r: "\u001b[0m";

    sep, (b + (.title // "untitled") + r), sep, "",

    (g + "ID:" + r + "       " + $id),
    (g + "Status:" + r + "   " + (.status // "unknown")),
    (g + "Priority:" + r + " P" + ((.priority // 2) | tostring)),
    (g + "Type:" + r + "     " + (.issue_type // "task")),
    (g + "Assignee:" + r + " " + (.owner // "unassigned")),
    (g + "Repo:" + r + "     " + $repo),
    "",

    (if (.description // "") != "" then
      b + "Description:" + r + "\n" + (.description | split("\n")[0:20] | join("\n")) + "\n"
    else empty end),

    (if ((.dependencies // []) | length) > 0 then
      b + "Blocked by:" + r + " (" + ((.dependencies // []) | length | tostring) + ")\n" +
      ([.dependencies[]? | "  - \(.id): \(.title // "untitled")"][0:5] | join("\n")) + "\n"
    else empty end),

    (if ((.labels // []) | length) > 0 then
      g + "Labels:" + r + " " + ((.labels // []) | join(", "))
    else empty end),

    (if (.created_at // "") != "" then
      g + "Created:" + r + "  " + (.created_at | split("T")[0])
    else empty end),

    (if (.updated_at // "") != "" then
      g + "Updated:" + r + "  " + (.updated_at | split("T")[0])
    else empty end)
  '
}

@test "preview renders owner field (not assignee)" {
  json='[{"id":"x-1","title":"Test","status":"open","priority":1,"issue_type":"task","owner":"alice@dev","created_at":"2026-01-15T00:00:00Z","updated_at":"2026-01-15T00:00:00Z"}]'

  run _run_preview_jq "$json" "x-1" "/tmp/repo"
  [ "$status" -eq 0 ]

  # Should show owner value, not "unassigned"
  stripped=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$stripped" == *"alice@dev"* ]]
  [[ "$stripped" != *"unassigned"* ]]
}

@test "preview derives dependency count from array" {
  json='[{"id":"x-2","title":"Blocked","status":"open","priority":2,"issue_type":"task","owner":"bob",
    "dependencies":[
      {"id":"x-10","title":"Dep one","status":"open"},
      {"id":"x-11","title":"Dep two","status":"closed"}
    ],
    "created_at":"2026-01-15T00:00:00Z","updated_at":"2026-01-15T00:00:00Z"}]'

  run _run_preview_jq "$json" "x-2" "/tmp/repo"
  [ "$status" -eq 0 ]

  stripped=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$stripped" == *"Blocked by:"* ]]
  [[ "$stripped" == *"(2)"* ]]
  [[ "$stripped" == *"x-10: Dep one"* ]]
  [[ "$stripped" == *"x-11: Dep two"* ]]
}

@test "preview handles no dependencies" {
  json='[{"id":"x-3","title":"Clean","status":"open","priority":2,"issue_type":"task","owner":"bob",
    "dependencies":[],"created_at":"2026-01-15T00:00:00Z","updated_at":"2026-01-15T00:00:00Z"}]'

  run _run_preview_jq "$json" "x-3" "/tmp/repo"
  [ "$status" -eq 0 ]

  stripped=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$stripped" != *"Blocked by:"* ]]
}

@test "preview handles missing optional fields" {
  # Minimal dolt-era response: no description, no dependencies, no labels
  json='[{"id":"x-4","title":"Minimal","status":"open","priority":2,"issue_type":"task","owner":"bob",
    "created_at":"2026-02-01T12:00:00Z","updated_at":"2026-02-01T12:00:00Z"}]'

  run _run_preview_jq "$json" "x-4" "/tmp/repo"
  [ "$status" -eq 0 ]

  stripped=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$stripped" == *"Minimal"* ]]
  [[ "$stripped" == *"x-4"* ]]
  [[ "$stripped" != *"Description:"* ]]
  [[ "$stripped" != *"Blocked by:"* ]]
  [[ "$stripped" != *"Labels:"* ]]
}

@test "preview shows description truncated to 20 lines" {
  # Build a 25-line description
  desc=$(printf 'line %s\n' $(seq 1 25) | jq -Rs '.')
  json="[{\"id\":\"x-5\",\"title\":\"Long desc\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"owner\":\"bob\",\"description\":$desc,\"created_at\":\"2026-01-01T00:00:00Z\",\"updated_at\":\"2026-01-01T00:00:00Z\"}]"

  run _run_preview_jq "$json" "x-5" "/tmp/repo"
  [ "$status" -eq 0 ]

  stripped=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$stripped" == *"line 20"* ]]
  [[ "$stripped" != *"line 21"* ]]
}
