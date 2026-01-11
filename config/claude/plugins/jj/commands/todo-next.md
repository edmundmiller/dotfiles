---
description: Move to next pending todo task
---

# Move to Next Todo

Switch to the next pending `[TODO]` task in the todo stack by using `jj edit`.

## Instructions

1. Find pending todos: `jj log -r '::@ & description(glob:"[TODO]*")' --no-graph -T change_id`
2. If pending todos exist:
   - Get the first pending todo's change_id
   - Use `jj edit <change-id>` to switch to it
   - Update its description from `[TODO]` to `[WIP]` using `jj describe -m "[WIP] <task-content>"`
   - Inform the user they're now working on this task
3. If no pending todos:
   - Inform the user all tasks are complete or in progress
   - Show the current todo status

## Example

```bash
# Find next todo
NEXT_TODO=$(jj log -r '::@ & description(glob:"[TODO]*")' --no-graph -T change_id --limit 1)

# Switch to it
jj edit "$NEXT_TODO"

# Mark as WIP
jj describe -m "[WIP] Task description here"
```

This command helps you systematically work through your todo stack.
