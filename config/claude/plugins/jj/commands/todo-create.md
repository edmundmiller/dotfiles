---
description: Create todo stack from task list
---

# Create Todo Stack

Create a stack of jj commits from a list of tasks. Each task becomes a `[TODO]` commit in the stack.

## Usage

`/jj-todo:create <task1> | <task2> | <task3>`

Or provide tasks as separate arguments.

## Instructions

1. Parse the task list from user input
2. For each task (in reverse order, so first task is on top):
   ```bash
   jj new -A @ -m "[TODO] <task-description>"
   ```
   The `-A @` flag inserts the new commit BEFORE the current working commit

3. After creating all todos, move to the first task:
   ```bash
   # Find first TODO
   FIRST_TODO=$(jj log -r '::@ & description(glob:"[TODO]*")' --no-graph -T change_id --limit 1)

   # Switch to it and mark as WIP
   jj edit "$FIRST_TODO"
   DESC=$(jj log -r @ --no-graph -T 'description' | sed 's/^\[TODO\] //')
   jj describe -m "[WIP] $DESC"
   ```

4. Show the created todo stack with `jj log -r '::@'`

## Example

```bash
# User runs: /jj-todo:create Design API | Implement handlers | Write tests

# Creates stack:
#   @  [WIP] Design API
#   │
#   ○  [TODO] Implement handlers
#   │
#   ○  [TODO] Write tests

# Output:
Created 3 tasks:
  • Design API (in progress)
  • Implement handlers (pending)
  • Write tests (pending)

View stack: jj log -r '::@'
```

## Notes

- Creates empty commits (no file changes yet)
- Oldest task at bottom of stack
- First task automatically marked as [WIP]
- All changes are undoable with `jj undo`
