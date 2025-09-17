#!/usr/bin/env bash
set -Eeuo pipefail

CMD=${1:-help}

if ! command -v gum >/dev/null 2>&1; then
  echo "gum not found. Install gum and re-run. Try: brew install gum, or sudo apt install gum, or go install github.com/charmbracelet/gum@latest" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found. Please install python3 for date calculations" >&2
  exit 1
fi

# Defaults derived from todo.txt ecosystem
TODO_DIR_DEFAULT="${TODO_DIR:-$HOME/todo}"
TODO_FILE_DEFAULT="${TODO_FILE:-$TODO_DIR_DEFAULT/todo.txt}"
DONE_FILE_DEFAULT="${DONE_FILE:-$TODO_DIR_DEFAULT/done.txt}"
REVIEW_DAYS_DEFAULT="${REVIEW_DAYS:-14}"

today() { date +%F; }

# Python-backed date math for portability
days_between() { python3 - "$@" <<'PY'
import sys, datetime
try:
    d1 = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%d").date()
    d2 = datetime.datetime.strptime(sys.argv[2], "%Y-%m-%d").date()
    print((d2 - d1).days)
except:
    print(9999)
PY
}

older_than() { # older_than YYYY-MM-DD N
  local d="$1" n="$2" t diff
  t=$(today)
  diff=$(days_between "$d" "$t" 2>/dev/null || echo 0)
  [ "${diff#-}" -ge "$n" ]
}

read_config() {
  TODO_FILE="$TODO_FILE_DEFAULT"
  REVIEW_DAYS="$REVIEW_DAYS_DEFAULT"
  while [ $# -gt 0 ]; do
    case "$1" in
      --file) shift; TODO_FILE="$1";;
      --days|-d) shift; REVIEW_DAYS="$1";;
      *) ;;
    esac
    shift || true
  done
  [ -f "$TODO_FILE" ] || { echo "todo file not found: $TODO_FILE"; exit 1; }
}

has_tag() { echo "$1" | grep -qE "(^|[[:space:]])$2:[^[:space:]]+"; }
get_tag() { echo "$1" | grep -oE "(^|[[:space:]])$2:[^[:space:]]+" | sed -E "s/^[[:space:]]*$2://"; }
set_tag() {
  local line="$1" key="$2" val="$3"
  if echo "$line" | grep -qE "(^|[[:space:]])$key:[^[:space:]]+"; then
    echo "$line" | sed -E "s/(^|[[:space:]])$key:[^[:space:]]+/\\1$key:$val/g"
  else
    echo "$line $key:$val"
  fi
}
remove_tag() { echo "$1" | sed -E "s/(^|[[:space:]])$2:[^[:space:]]+//g" | tr -s " " | sed 's/^ *//;s/ *$//'; }
is_done() { echo "$1" | grep -qE "^x(\s|$)"; }
normalize_space() { echo "$1" | sed -E 's/[[:space:]]+/ /g;s/^ *//;s/ *$//'; }

get_due() { get_tag "$1" "due"; }
set_due() { set_tag "$1" "due" "$2"; }
clear_due() { remove_tag "$1" "due"; }
get_reviewed() { get_tag "$1" "reviewed"; }
set_reviewed() { set_tag "$1" "reviewed" "$(today)"; }

get_priority() { echo "$1" | sed -nE 's/^\(([A-Z])\) .*/\1/p'; }
set_priority() {
  local line="$1" prio="$2"
  line=$(echo "$line" | sed -E 's/^\([A-Z]\) //')
  if [ "$prio" = "none" ]; then echo "$line"; else echo "($prio) $line"; fi
}

needs_review() {
  local line="$1"
  is_done "$line" && return 1
  
  # Skip empty lines
  [ -z "$(echo "$line" | tr -d '[:space:]')" ] && return 1
  
  local reviewed=$(get_reviewed "$line")
  local due=$(get_due "$line")
  
  # Check if reviewed date is old or missing
  if [ -z "$reviewed" ] || older_than "$reviewed" "$REVIEW_DAYS"; then
    return 0
  fi
  
  # Check if due soon or overdue
  if [ -n "$due" ]; then
    local t=$(today)
    local ddiff
    ddiff=$(days_between "$t" "$due" 2>/dev/null || echo 9999)
    # due within 3 days or overdue
    [ "$ddiff" -le 3 ] && return 0
    [ "$ddiff" -lt 0 ] && return 0
  fi
  return 1
}

load_tasks() { 
  TASKS=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    TASKS+=("$line")
  done < "$TODO_FILE"
}

save_tasks() {
  local tmp
  tmp=$(mktemp)
  printf "%s\n" "${TASKS[@]}" > "$tmp"
  cp "$TODO_FILE" "$TODO_FILE.bak.$(date +%s)"
  mv "$tmp" "$TODO_FILE"
}

render_task() {
  local line="$1"
  local prio=$(get_priority "$line")
  local due=$(get_due "$line")
  local reviewed=$(get_reviewed "$line")
  
  gum style --foreground 212 --bold "$line"
  [ -n "$prio" ] && gum style --foreground 214 "Priority: $prio"
  [ -n "$due" ] && gum style --foreground 39 "Due: $due"
  [ -n "$reviewed" ] && gum style --foreground 245 "Last reviewed: $reviewed"
}

review_loop() {
  local idxs=()
  for i in "${!TASKS[@]}"; do
    local line="${TASKS[$i]}"
    if needs_review "$line"; then idxs+=("$i"); fi
  done

  if [ "${#idxs[@]}" -eq 0 ]; then
    gum style --foreground 82 "🎉 No tasks need review. You're all caught up!"
    exit 0
  fi

  gum style --foreground 33 --bold "📋 Found ${#idxs[@]} tasks needing review"
  echo

  local processed=0 modified=0 skipped=0
  for i in "${idxs[@]}"; do
    # Check if task still exists (might have been deleted)
    [ -z "${TASKS[$i]:-}" ] && continue
    
    clear
    gum style --border rounded --margin "1" --padding "1 2" --foreground 212 "Task $((processed+1)) of ${#idxs[@]}"
    render_task "${TASKS[$i]}"
    echo
    local action
    action=$(gum choose "Modify" "Mark reviewed" "Set due date" "Priority" "Snooze" "Delete" "Skip" --header "What would you like to do?")
    case "$action" in
      "Modify")
        local edited
        edited=$(gum input --placeholder "Edit the task text" --value "${TASKS[$i]}")
        if [ -n "$edited" ] && [ "$edited" != "${TASKS[$i]}" ]; then
          TASKS[$i]=$(normalize_space "$edited")
          modified=$((modified+1))
          gum style --foreground 82 "✓ Task updated"
        else
          gum style --foreground 245 "No changes made"
        fi
        ;;
      "Mark reviewed")
        TASKS[$i]=$(set_reviewed "${TASKS[$i]}")
        modified=$((modified+1))
        gum style --foreground 82 "✓ Marked as reviewed"
        ;;
      "Set due date")
        local current_due=$(get_due "${TASKS[$i]}")
        local new_due
        new_due=$(gum input --placeholder "YYYY-MM-DD (empty to clear)" --value "$current_due")
        if [ -n "$new_due" ]; then
          if date -d "$new_due" >/dev/null 2>&1 || date -j -f "%Y-%m-%d" "$new_due" >/dev/null 2>&1; then
            TASKS[$i]=$(set_due "${TASKS[$i]}" "$new_due")
            modified=$((modified+1))
            gum style --foreground 82 "✓ Due date set to $new_due"
          else
            gum style --foreground 196 "✗ Invalid date format"
          fi
        else
          TASKS[$i]=$(clear_due "${TASKS[$i]}")
          modified=$((modified+1))
          gum style --foreground 82 "✓ Due date cleared"
        fi
        ;;
      "Priority")
        local prio=$(get_priority "${TASKS[$i]}")
        local newp
        newp=$(gum choose "A" "B" "C" "D" "none" --header "Current priority: ${prio:-none}")
        TASKS[$i]=$(set_priority "${TASKS[$i]}" "$newp")
        modified=$((modified+1))
        if [ "$newp" = "none" ]; then
          gum style --foreground 82 "✓ Priority removed"
        else
          gum style --foreground 82 "✓ Priority set to $newp"
        fi
        ;;
      "Snooze")
        local ndays
        ndays=$(gum input --placeholder "Days to snooze (e.g., 7)" --value "7")
        if [[ "$ndays" =~ ^[0-9]+$ ]]; then
          local rvw_date
          rvw_date=$(python3 - "$ndays" <<'PY'
import sys, datetime
n=int(sys.argv[1])
print((datetime.date.today()+datetime.timedelta(days=n)).strftime("%Y-%m-%d"))
PY
)
          TASKS[$i]=$(set_tag "${TASKS[$i]}" "reviewed" "$rvw_date")
          modified=$((modified+1))
          gum style --foreground 82 "✓ Snoozed until $rvw_date"
        else
          gum style --foreground 196 "✗ Invalid number of days"
        fi
        ;;
      "Delete")
        if gum confirm "Are you sure you want to delete this task?"; then
          TASKS[$i]=""
          modified=$((modified+1))
          gum style --foreground 196 "✗ Task deleted"
        else
          gum style --foreground 245 "Task kept"
        fi
        ;;
      "Skip")
        skipped=$((skipped+1))
        gum style --foreground 245 "→ Skipped"
        ;;
    esac
    processed=$((processed+1))
    echo
    sleep 0.3
  done

  # compact array by removing deleted entries
  local new_tasks=()
  for task in "${TASKS[@]}"; do
    [ -n "$task" ] && new_tasks+=("$task")
  done
  TASKS=("${new_tasks[@]}")
  
  save_tasks
  gum style --foreground 33 --bold "✅ Review complete!"
  gum style --foreground 245 "Processed: $processed | Modified: $modified | Skipped: $skipped"
}

case "$CMD" in
  review)
    shift || true
    read_config "$@"
    load_tasks
    review_loop
    ;;
  help|--help|-h|"")
    cat <<EOF
task.sh - Interactive todo.txt task review tool

USAGE:
  task.sh review [--file PATH] [--days N]
  task.sh help

COMMANDS:
  review    Start interactive review session
  help      Show this help message

OPTIONS:
  --file PATH   Use specific todo.txt file (default: \$TODO_FILE or ~/todo/todo.txt)
  --days N      Review tasks older than N days (default: 14)

ENVIRONMENT VARIABLES:
  TODO_DIR      Directory containing todo files (default: ~/todo)
  TODO_FILE     Path to todo.txt file (default: \$TODO_DIR/todo.txt)
  DONE_FILE     Path to done.txt file (default: \$TODO_DIR/done.txt)
  REVIEW_DAYS   Default days before review needed (default: 14)

EXAMPLES:
  task.sh review                           # Review with defaults
  task.sh review --days 7                  # Review tasks older than 7 days
  task.sh review --file ~/work/todo.txt    # Review specific file
  REVIEW_DAYS=21 task.sh review            # Review tasks older than 21 days

REVIEW POLICY:
  Tasks need review if:
  - No 'reviewed:YYYY-MM-DD' tag, or tag is older than N days, OR
  - Has 'due:YYYY-MM-DD' that's within 3 days or overdue

ACTIONS DURING REVIEW:
  - Modify: Edit the complete task text
  - Mark reviewed: Add/update reviewed:today
  - Set due date: Add/update/clear due:YYYY-MM-DD
  - Priority: Set priority (A), (B), (C), (D), or none
  - Snooze: Set reviewed date N days in the future
  - Delete: Remove the task completely
  - Skip: Leave task unchanged for this session

For more information, see: https://github.com/charmbracelet/gum
EOF
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    echo "Try: task.sh help" >&2
    exit 1
    ;;
esac
