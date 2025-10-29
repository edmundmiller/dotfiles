---
name: Working with Jujutsu Version Control
description: Understand and work with Jujutsu (jj) version control system. Use when the user mentions commits, changes, version control, or working with jj repositories. Helps with stack-based commit workflows, change curation, and jj best practices.
---

# Working with Jujutsu Version Control

## Core Concepts

**Jujutsu (jj)** is Git-compatible VCS with:

- **Change-based**: Unique IDs persist through rewrites
- **Auto-snapshotting**: Working copy snapshotted before each operation
- **Stack-based**: Build commits in a stack
- **Undoable**: All ops in `jj op log`, use `jj op restore` to time travel

**vs Git:** No staging area, edit any commit (`jj edit`), conflicts stored in commits, auto working copy mgmt

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

1. Make changes in `@` (including new files - they'll be tracked automatically)
2. Describe with `jj describe -m "message"` (or `/jj:commit`)
3. Create new commit on top with `jj new`
4. Repeat

**Note:** New untracked files are automatically tracked when using `/jj:commit`, so you don't need to manually run `jj file track`.

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

Every `jj` command auto-snapshots working copy. Use `jj op log` to view history, `jj undo` for last op, or `jj op restore <id>` for time travel.

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
- New untracked files are automatically tracked before committing

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

- **Check state**: `jj status`, `jj log -r @`, `jj diff`
- **Stack commit**: `/jj:commit "message"` or `jj describe -m "..." && jj new`
- **Fix mistakes**: `jj undo`, `jj op restore <id>`, `jj edit @-`
- **Reorganize**: `/jj:split test`, `/jj:squash`, `jj rebase -r @ -d X`
