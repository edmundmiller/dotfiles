---
description: Show todo list as jj commit graph
---

# Show JJ Todo Status

Display the current todo list as a jj commit graph. Each commit represents a task:
- `[TODO]` = pending task (empty commit)
- `[WIP]` = work in progress (current working commit)
- No prefix = completed task (regular commit with changes)

The jj log graph IS your todo list visualization.

## Instructions

1. Run `jj log -r '::@'` to show the todo stack
2. Optionally use `jj log -r '::@' -T 'if(description.starts_with("[TODO]") || description.starts_with("[WIP]"), description ++ " (todo)", description)'` to highlight todos
3. Provide a clear summary of:
   - Total tasks
   - Pending tasks ([TODO])
   - In progress tasks ([WIP])
   - Completed tasks ([DONE])

## Example Output Format

```
Current Todo Stack:

  @  [WIP] Create jj-todo PostToolUse hook
  │
  ○  [TODO] Create jj-todo skill and commands
  │
  ○  [TODO] Register hook in plugin configuration
  │
  ○  Design jj commit-based todo architecture

Status:
  • Total: 4 tasks
  • In Progress: 1
  • Pending: 2
  • Completed: 1 (no prefix)
```

Use `jj edit <change-id>` to switch to a different task.
