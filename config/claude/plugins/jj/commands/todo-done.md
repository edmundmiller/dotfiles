---
description: Mark current task as done and move to next
---

# Mark Task Done

Mark the current `[WIP]` task as completed (remove prefix) and move to the next pending task.

## Instructions

1. Update current commit description from `[WIP]` to completed (remove prefix):
   ```bash
   # Get current description without WIP prefix
   DESC=$(jj log -r @ --no-graph -T 'description' | sed 's/^\[WIP\] //')

   # Mark as done (no prefix = completed)
   jj describe -m "$DESC"
   ```

2. Create a new working commit:
   ```bash
   jj new
   ```

3. Find and switch to next pending todo (if any):
   ```bash
   NEXT_TODO=$(jj log -r '::@ & description(glob:"[TODO]*")' --no-graph -T change_id --limit 1)

   if [ -n "$NEXT_TODO" ]; then
     jj edit "$NEXT_TODO"
     # Get description without TODO prefix
     DESC=$(jj log -r @ --no-graph -T 'description' | sed 's/^\[TODO\] //')
     jj describe -m "[WIP] $DESC"
   fi
   ```

4. Report status to user:
   - What task was completed
   - What task is now active (or that all tasks are done)

## Example Output

```
✅ Completed: Create jj-todo PostToolUse hook
🚀 Now working on: Create jj-todo skill and commands
```

This command provides a smooth workflow for completing tasks and moving to the next one.
