# Custom Async Taskwarrior Prompt for Powerlevel10k

This document describes how to create a custom async Taskwarrior segment for Powerlevel10k, based on the `prompt_jj()` implementation in `config/zsh/.p10k.zsh`.

## When to Use This

The built-in `taskwarrior` segment (currently enabled) is sufficient for most cases. Consider a custom async implementation when:

- **Context-aware filtering**: Show tasks filtered by current project directory
- **More data points**: Display today's tasks, blocked tasks, active task
- **Performance**: Task database becomes large and `task count` becomes slow (>50ms)
- **Custom logic**: Need special filtering or formatting beyond overdue/pending

## Architecture

The pattern uses `zsh-async` to run task queries in a background worker, preventing prompt lag. This mirrors the existing `prompt_jj()` implementation.

### Components

1. **Worker function** (`taskwarrior_status`): Runs in background, gathers data
2. **Callback function** (`taskwarrior_status_callback`): Receives results, triggers redraw
3. **Prompt function** (`prompt_taskwarrior`): Displays cached/fresh status

## Implementation

Add to `config/zsh/.p10k.zsh` inside the main `()` function block:

```zsh
# ============================================================================
# TASKWARRIOR Async Prompt
# ============================================================================

function taskwarrior_status() {
  emulate -L zsh

  local grey='%244F'
  local green='%2F'
  local red='%196F'
  local yellow='%3F'
  local cyan='%6F'

  # Gather counts
  local pending=$(task +PENDING count 2>/dev/null)
  local overdue=$(task +OVERDUE count 2>/dev/null)
  local today=$(task +SCHEDULED.before:tomorrow +PENDING count 2>/dev/null)
  local blocked=$(task +BLOCKED +PENDING count 2>/dev/null)
  local active=$(task +ACTIVE count 2>/dev/null)

  # Optional: context-aware filtering based on current directory
  # Uncomment to enable project-based filtering
  # local project_filter=""
  # if [[ -f .taskwarrior-project ]]; then
  #   project_filter="project:$(cat .taskwarrior-project)"
  #   pending=$(task $project_filter +PENDING count 2>/dev/null)
  #   overdue=$(task $project_filter +OVERDUE count 2>/dev/null)
  # fi

  local res=""

  # Show active task indicator
  (( active > 0 )) && res+="${green}▶ "

  # Show overdue with warning color
  if (( overdue > 0 )); then
    res+="${red}!${overdue}/"
  fi

  # Show pending count
  res+="${cyan}${pending}"

  # Show today's tasks if any
  (( today > 0 )) && res+=" ${yellow}⏰${today}"

  # Show blocked tasks if any
  (( blocked > 0 )) && res+=" ${grey}⏸${blocked}"

  echo $res
}

function taskwarrior_status_callback() {
  emulate -L zsh
  if [[ $2 -ne 0 ]]; then
    typeset -g p10k_taskwarrior_status=
  else
    typeset -g p10k_taskwarrior_status="$3"
  fi
  typeset -g p10k_taskwarrior_stale= p10k_taskwarrior_updated=1
  p10k display -r
}

# Initialize async worker
async_start_worker        taskwarrior_status_worker -u
async_unregister_callback taskwarrior_status_worker
async_register_callback   taskwarrior_status_worker taskwarrior_status_callback

function prompt_taskwarrior() {
  emulate -L zsh
  (( $+commands[task] )) || return

  typeset -g p10k_taskwarrior_stale=1 p10k_taskwarrior_updated=

  # Show stale cached status while updating (grey)
  p10k segment -f grey -c '$p10k_taskwarrior_stale' -e -t '$p10k_taskwarrior_status'
  # Show fresh status when async completes (full color)
  p10k segment -c '$p10k_taskwarrior_updated' -e -t '$p10k_taskwarrior_status'

  async_job taskwarrior_status_worker taskwarrior_status
}
```

### Enable the Segment

Replace `taskwarrior` with `my_taskwarrior` (or whatever you name it) in the prompt elements:

```zsh
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  my_taskwarrior            # custom async taskwarrior
  command_execution_time
  # ...
)
```

## Display Format Examples

The custom segment can display richer information:

| Scenario | Display |
|----------|---------|
| 28 pending, none overdue | `󰱒 28` |
| 28 pending, 3 overdue | `󰱒 !3/28` |
| Active task running | `󰱒 ▶ 28` |
| 5 tasks due today | `󰱒 28 ⏰5` |
| 2 blocked tasks | `󰱒 28 ⏸2` |
| Full example | `󰱒 ▶ !3/28 ⏰5 ⏸2` |

## Context-Aware Filtering

To show only tasks for the current project:

1. Create a `.taskwarrior-project` file in project directories:
   ```bash
   echo "dotfiles" > ~/dotfiles/.taskwarrior-project
   ```

2. Uncomment the context-aware section in `taskwarrior_status()`

3. The segment will filter tasks by `project:dotfiles` when in that directory

## Performance Notes

- The built-in segment runs synchronously but `task count` is typically ~12ms
- The async pattern prevents any prompt lag regardless of query time
- Multiple `task count` calls add up; async batches them in background
- Cache is refreshed on each prompt, showing stale data briefly (grey color)

## Dependencies

- `zsh-async`: Already loaded for the jj segment
- Taskwarrior (`task`): Must be in PATH

## See Also

- `prompt_jj()` in `config/zsh/.p10k.zsh` - Reference async implementation
- [Powerlevel10k documentation](https://github.com/romkatv/powerlevel10k)
- [zsh-async](https://github.com/mafredri/zsh-async)
