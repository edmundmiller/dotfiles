---
name: Working with Jujutsu Version Control
description: Understand and work with Jujutsu (jj) version control system. Use when the user mentions commits, changes, version control, or working with jj repositories. Helps with stack-based commit workflows, change curation, and jj best practices.
---

# Working with Jujutsu Version Control

## Core Concepts

**Jujutsu (jj)** is a Git-compatible version control system with a different mental model:

- **Change-based, not commit-based**: Every change has a unique ID that persists through rewrites
- **Automatic snapshotting**: Working copy is automatically snapshotted before each operation
- **Stack-based workflow**: Build commits on top of each other in a stack
- **Everything is undoable**: All operations recorded in `jj op log`, use `jj op restore` to time travel

**Key differences from Git:**
- No staging area (changes are always in commits)
- Edit any commit directly with `jj edit`
- Conflicts stored in commits, not blocking
- Automatic working copy management

## Working Copy Model

The **working copy** (`@`) is always a commit:

```bash
# Current commit
jj log -r @

# Parent commit
jj log -r @-

# Stack of recent commits
jj log -r 'ancestors(@, 5)'
```

**State tracking:**
- If `@` is empty with no description → Fresh start, ready for changes
- If `@` has changes but no description → Work done, needs description
- If `@` has description and changes → Can stack with `jj new`
- If `@` has description, no changes → Already stacked, ready for new work

## Stack-Based Workflow

**Building the stack:**
1. Make changes in `@`
2. Describe with `jj describe -m "message"` (or `/jj:commit`)
3. Create new commit on top with `jj new`
4. Repeat

**Why stack commits:**
- Review commits individually
- Reorder/reorganize commits easily
- Ship commits incrementally
- Keep clean, focused history

## Plan-Driven Workflow

This repository uses a **plan-first** approach:

1. **Plan created (start)**: When starting substantial work, create "plan:" commit describing intent
2. **Work happens**: Implement the plan, changes tracked in `@`
3. **Describe reality (end)**: Replace "plan:" with actual work done using `/jj:commit`

**TodoWrite integration:**
- One commit per major todo item
- Use `jj new` when moving to next todo
- Creates atomic, reviewable commits

## Automatic Snapshotting

Every `jj` command automatically snapshots the working copy:

- **No manual saves needed**: Changes tracked automatically
- **Full operation history**: `jj op log` shows everything
- **Easy undo**: `jj undo` or `jj op restore`
- **Time travel**: Restore to any previous state

**Examples:**
```bash
jj op log              # View all operations
jj op restore abc123   # Restore to specific operation
jj undo                # Undo last operation
```

## When to Suggest JJ Commands

**Viewing state:**
- `jj status` - Check working copy changes
- `jj log` - View commit history
- `jj show` - Show specific commit
- `jj diff` - Show changes in working copy

**Creating commits:**
- Use `/jj:commit` command (don't run `jj describe` directly unless in command context)
- Suggest when user has made substantial changes
- Suggest when plan needs updating to reflect reality

**Organizing commits:**
- Use `/jj:split <pattern>` when changes mix concerns (e.g., tests + implementation)
- Use `/jj:squash` when multiple WIP commits for same feature
- Don't suggest curation for simple, focused changes

**Undoing mistakes:**
- `jj undo` - Undo last operation
- `jj op restore` - Restore to earlier state
- `jj abandon` - Discard bad commits

## Slash Commands Available

This plugin provides user-invoked slash commands:

- **`/jj:commit [message]`** - Stack a commit with intelligent message generation
- **`/jj:split <pattern>`** - Split commit by pattern (test, docs, config)
- **`/jj:squash [revision]`** - Merge commits in the stack
- **`/jj:cleanup`** - Remove empty workspaces

**When to mention slash commands:**
- User asks "how do I commit" → Mention `/jj:commit`
- User has mixed changes → Suggest `/jj:split test` or similar
- User mentions WIP commits → Suggest `/jj:squash`

## Git Translation

This repository **blocks git commands** via hook. If user tries `git`:

- Read-only commands allowed (status, log, diff, show, blame)
- Write commands blocked with jj suggestion
- Always prefer jj equivalents:
  - `git status` → `jj status`
  - `git commit` → `/jj:commit`
  - `git log` → `jj log`
  - `git checkout` → `jj new`

## Best Practices

**Do:**
- Stack commits as you work
- Describe changes clearly (what and why)
- Use plan-driven workflow for substantial tasks
- Leverage `jj op log` for safety
- Split mixed concerns into separate commits

**Don't:**
- Mix git and jj commands (hooks prevent this)
- Leave substantial work undescribed at session end
- Create monolithic commits with unrelated changes
- Forget that everything is undoable

## Common Operations

**Check current state:**
```bash
jj status           # Working copy changes
jj log -r @         # Current commit
jj diff             # Uncommitted changes
```

**Stack new commit:**
```bash
# Using slash command (preferred)
/jj:commit "feat: add login"

# Manual (in command context)
jj describe -m "feat: add login"
jj new
```

**Fix mistakes:**
```bash
jj undo                    # Undo last operation
jj op restore <operation>  # Restore to earlier point
jj edit @-                 # Edit parent commit
```

**Reorganize commits:**
```bash
/jj:split test      # Split tests from implementation
/jj:squash          # Merge current into parent
jj rebase -r @ -d X # Move commit to different base
```

## When This Skill Activates

Use this Skill when:
- User mentions commits, committing, or version control
- User asks about jj commands or workflow
- Working with changes that need organizing
- User asks "how do I" questions about version control
- Need to explain jj concepts or suggest best practices
- Translating git knowledge to jj equivalents
