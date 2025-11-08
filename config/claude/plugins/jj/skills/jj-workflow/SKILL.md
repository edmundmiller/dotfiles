---
name: Working with Jujutsu Version Control
description: Understand and work with Jujutsu (jj) version control system. Use when the user mentions commits, changes, version control, or working with jj repositories. Helps with stack-based commit workflows, change curation, and jj best practices.
allowed-tools: Bash(jj status:*), Bash(jj log:*), Bash(jj show:*), Bash(jj diff:*)
---

# Working with Jujutsu Version Control

## Core Concepts

**Jujutsu (jj)** - Git-compatible VCS with:

- **Change-based**: Unique IDs persist through rewrites
- **Auto-snapshotting**: Working copy snapshotted before each operation
- **Stack-based**: Build commits in a stack
- **Undoable**: All ops in `jj op log`, use `jj op restore` to time travel

**vs Git:** No staging area, edit any commit (`jj edit`), conflicts stored in commits

## Working Copy (`@`)

Current commit is always `@`:

- `jj log -r @` - Current commit
- `jj log -r @-` - Parent commit
- `jj log -r 'ancestors(@, 5)'` - Recent stack

**State:**

- Empty, no description → Ready for changes
- Has changes, no description → Needs description
- Has description + changes → Can stack with `jj new`
- Has description, no changes → Ready for new work

## Stack-Based Workflow

1. Make changes in `@` (new files tracked automatically via `/jj:commit`)
2. Describe: `jj describe -m "message"` or `/jj:commit`
3. Stack: `jj new`
4. Repeat

**Why stack:** Individual review, easy reordering, incremental shipping, clean history

## Plan-Driven Workflow

1. **Start**: Create "plan:" commit describing intent
2. **Work**: Implement the plan
3. **End**: Replace "plan:" with actual work using `/jj:commit`

**TodoWrite:** One commit per major todo, `jj new` between todos

## Automatic Snapshotting

Every `jj` command auto-snapshots. Use `jj op log`, `jj undo`, or `jj op restore <id>` for time travel.

## When to Suggest Commands

**Viewing state:** `jj status`, `jj log`, `jj show`, `jj diff`

**Creating commits:**

- Use `/jj:commit` (not `jj describe` directly)
- Suggest when user has substantial changes or plan needs updating

**Organizing commits:**

- `/jj:split <pattern>` when mixing concerns (tests+code)
- `/jj:squash` for multiple WIP commits
- Don't suggest for simple, focused changes

**Undoing:** `jj undo`, `jj op restore`, `jj abandon`

## Slash Commands

- `/jj:commit [message]` - Stack commit with message generation
- `/jj:split <pattern>` - Split by pattern (test, docs, config)
- `/jj:squash [revision]` - Merge commits
- `/jj:cleanup` - Remove empty workspaces

## Git Translation

Repository blocks git write commands via hook. Prefer jj equivalents:

- `git status` → `jj status`
- `git commit` → `/jj:commit`
- `git log` → `jj log`
- `git checkout` → `jj new`

## Best Practices

**Do:** Stack commits, describe clearly (what/why), use plan-driven workflow, leverage `jj op log`, split mixed concerns

**Don't:** Mix git/jj, leave work undescribed, create monolithic commits, forget everything is undoable
