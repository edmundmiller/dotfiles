---
name: Undoing Operations in Jujutsu
description: Help users undo mistakes and recover from errors in jj. Use when the user explicitly mentions 'jj undo', 'undo operation', or 'restore operation'. Covers quick undo, multiple undo scenarios, and redo workflows.
allowed-tools: Bash(jj undo:*), Bash(jj op log:*), Bash(jj op restore:*), Bash(jj log:*), Bash(jj status:*), Bash(jj diff:*)
---

# Undoing Operations in Jujutsu

## Core Undo Concept

**Everything is undoable in jj.** Every operation is recorded and can be reversed. There's no need to fear making mistakes.

**Key insight:** Jj auto-snapshots the working copy before every operation, so you can always go back.

## Quick Undo: The Most Useful Command

### `jj undo` - Reverse the Last Operation

**When to use:** You just ran a command and immediately realized it was wrong.

**What it does:** Reverses the most recent operation, restoring the repository to its previous state.

**Examples:**

```bash
# Accidentally squashed the wrong commits
jj squash
jj undo                    # Reverses the squash

# Described a commit with the wrong message
jj describe -m "wrong message"
jj undo                    # Restores previous description

# Split commits incorrectly
/jj:split test
jj undo                    # Reverses the split
```

**Important:** `jj undo` affects the repository state, but working copy files update automatically to match.

## Multiple Undo

### Undoing Several Operations

You can run `jj undo` multiple times to step backwards through operations:

```bash
jj undo                    # Undo most recent operation
jj undo                    # Undo the one before that
jj undo                    # Keep going back
```

**Workflow:**

1. Run `jj op log` to see what operations you want to undo
2. Run `jj undo` once for each operation you want to reverse
3. Check `jj status` to verify the result

**Tip:** Each `jj undo` is itself an operation, so you can undo an undo (see Redo section).

## Redo After Undo

### Using Operation Log to Redo

If you undo too many operations, you can "redo" by looking at the operation log:

**Method 1: Undo the undo**

```bash
jj undo                    # Undoes the last undo operation
```

**Method 2: Restore to specific operation**

```bash
jj op log                  # Find the operation ID you want
jj op restore <op-id>      # Jump to that operation
```

**Example:**

```bash
jj squash                  # Operation A
jj undo                    # Operation B (undoes A)
jj undo                    # Operation C (undoes B, effectively redoing A)
```

## When to Use Different Undo Approaches

### `jj undo` vs `jj op restore` vs `jj abandon`

**Use `jj undo` when:**

- ✅ You want to reverse the most recent operation
- ✅ You need a simple, immediate reversal
- ✅ You want to step back through operations one at a time
- ✅ You're trying things and want an easy undo button

**Use `jj op restore <id>` when:**

- ✅ You need to jump back multiple operations at once
- ✅ You know the specific operation ID you want to restore to
- ✅ You want to skip over several intermediate operations
- ✅ You're recovering from a complex multi-step mistake

**Use `jj abandon` when:**

- ✅ You want to delete specific commits (not operations)
- ✅ You're cleaning up commits, not undoing operations
- ✅ You want the commits gone permanently (though still in op log)

**Key difference:** `jj undo` and `jj op restore` affect operations (what commands you ran), while `jj abandon` affects commits (what changes exist).

## Common Mistake Recovery Patterns

### 1. Wrong Commit Message

```bash
jj describe -m "typo in mesage"
jj undo
jj describe -m "correct message"
```

### 2. Squashed Wrong Commits

```bash
jj squash                  # Oops, wrong parent
jj undo
# Now squash correctly
```

### 3. Split Incorrectly

```bash
/jj:split test             # Split wasn't quite right
jj undo
/jj:split docs            # Try different pattern
```

### 4. Created New Commit Too Early

```bash
jj new                     # Oops, wasn't ready for new commit
jj undo
# Continue working in current commit
```

### 5. Multiple Related Mistakes

```bash
jj undo                    # Undo most recent
jj undo                    # Undo the one before
jj undo                    # Keep going until clean state
# Or use jj op log to find target and jj op restore
```

## Safety Notes

### What Undo Affects

**Does affect:**

- ✅ Commit history and change IDs
- ✅ Bookmark positions
- ✅ Working copy state (updates automatically)
- ✅ Descriptions and metadata

**Does NOT affect:**

- ❌ The operation log itself (undos are recorded)
- ❌ Remote repositories until you push
- ❌ Other people's work in concurrent operations

### Can't Lose Work

**Important:** Even if you undo operations, the changes still exist in the operation log. You can always:

- View old state with `jj log --at-op=<old-op-id>`
- Restore to any previous operation with `jj op restore`
- See all operations with `jj op log`

**Bottom line:** In jj, you can't accidentally lose work. The operation log is your safety net.

## When to Suggest Undo to Users

**Immediately suggest `jj undo` when:**

- User expresses regret about a command
- User says "wait, that was wrong"
- User wants to try a different approach
- An operation produced unexpected results

**Suggest exploring operation log when:**

- User wants to see what they've done
- User needs to go back multiple steps
- User is recovering from complex mistakes
- User asks "what did I do?" or "how do I get back?"

**Proactive help:**

- After complex operations (squash, split), mention undo is available
- When user is learning jj, remind them everything is undoable
- If an operation might be risky, mention undo safety net first

## Integration with Other Workflows

### With `/jj:commit`

```bash
/jj:commit                 # Claude generates commit message
# If message isn't quite right:
jj undo                    # Undo the description
/jj:commit                 # Try again with different context
```

### With Stack-Based Workflow

```bash
jj new                     # Start new commit
# Realize you're not done with previous commit yet:
jj undo                    # Go back to previous commit
# Continue working
```

### With Plan-Driven Workflow

```bash
/jj:commit                 # Replace "plan:" with implementation
# Realize plan needs more work:
jj undo                    # Restore "plan:" description
# Continue implementing
```

## Quick Reference

**Most common commands:**

- `jj undo` - Reverse last operation (use multiple times to go back further)
- `jj op log` - See what operations can be undone
- `jj status` - Verify state after undo
- `jj log` - See commit history after undo

**Remember:** Everything is recorded, everything is undoable, you can't lose work.
