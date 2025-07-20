# Complete Tasks

Mark tasks as completed and review your accomplishments.

## Quick Completion

Let me help you mark tasks as done. First, let's see your current pending tasks:

```bash
task list
```

## Completion Methods

You can complete tasks by:

1. **Task ID**: `task 15 done` 
2. **Description search**: `task /login bug/ done`
3. **Multiple tasks**: `task 1,3,7 done`

## Review Today's Work

See what you've accomplished today:

```bash
echo "=== COMPLETED TODAY ===" && \
task completed end.after:today && \
echo && echo "=== COMPLETION SUMMARY ===" && \
task completed end.after:today count && \
echo "tasks completed today"
```

## Smart Completion Assistant

Tell me which task you want to complete, and I can:
- Find the exact task ID for you
- Mark it as done
- Show related tasks that might be ready to start
- Update any dependent tasks
- Add completion notes if needed

## Example Completions

```bash
# Complete a specific task
task 42 done

# Complete with annotation
task 15 done "Fixed by updating authentication middleware"

# Complete multiple related tasks
task +bug project:auth done
```

Which task would you like to mark as completed?