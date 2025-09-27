## Critical Instructions

- **ALWAYS write over the source file you're editing.** Don't make "_enhanced", "_fixed", "_updated", or "_v2" versions. We use Git/JJ for version control. If unsure, commit first then overwrite.
- Don't make "dashboards" or figures with a lot of plots in one image file. It's hard for AIs to figure out what all is going on.
- When the user requests code examples, setup or configuration steps, or library/API documentation use context7.

## Python Scripts

Use a uv shebang for Python scripts:
```
#!/usr/bin/env -S uv run --script
#
# /// script
# dependencies = [
#   "requests",
# ]
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
```
It can just be run with `uv run`

## Jujutsu (JJ) Version Control

This project uses jujutsu (jj), a Git-compatible VCS. Claude Code is configured with **autonomous commit stacking and curation**.

### Autonomous Workflow

**Phase 1: Implementation** - Make commits as you work:
```bash
/jj:commit "feat: add login UI"      # Stack commits
/jj:commit "add validation logic"    # Keep stacking
/jj:commit "add tests"               # Auto-generated or custom messages
```

**Phase 2: Curation** - Clean up your commits:
```bash
/jj:split test        # Separate tests from implementation
/jj:squash            # Merge WIP/fixup commits
```

**Phase 3: Session End** - Stop hook shows your stack:
```
📦 Workspace: claude-1234
**Commit stack:**
abc: feat: authentication implementation
def: test: authentication tests
```

### Commands (4 total)

**`/jj:commit [message]`** - Stack a commit
- Auto-generates message from file patterns (test/docs/fix/feat)
- Creates new commit on top of stack
- Usage: `/jj:commit` or `/jj:commit "feat: add auth"`

**`/jj:squash [revision]`** - Merge commits
- Default: merges current @ into parent
- With revision: merges specific commit
- Usage: `/jj:squash` or `/jj:squash abc123`

**`/jj:split <pattern>`** - Split by pattern
- Smart patterns: `test`, `docs`, `config`, `*.md`, `*.test.ts`
- Moves matching files to separate commit
- Usage: `/jj:split test` or `/jj:split docs`

**`/jj:cleanup`** - Remove empty workspaces
- Maintenance command for workspace cleanup

### Automatic Behavior

**On session start:**
- Auto-creates isolated workspace in `.jj-workspaces/claude-<timestamp>/`
- Enables parallel Claude sessions without conflicts

**On file edits:**
- Auto-updates commit description: `WIP: file1.js, file2.py, ...`

**On session end:**
- Shows commit stack with curation tips

### Key Principles

- **Stack commits** - Each `/jj:commit` creates new commit on top
- **Pattern-based split** - Use descriptions, not file lists
- **Autonomous curation** - Recognize and fix messy commits
- **Everything undoable** - Use `jj undo` for any mistakes
- **Workspace isolation** - Parallel sessions work independently

### Manual JJ Commands

For advanced operations:
```bash
jj log           # Browse commit history
jj diff          # See current changes
jj undo          # Undo last operation
jj rebase        # Reorganize commits
jj abandon       # Discard bad commits
```

**When to curate:**
- Multiple WIP commits for same feature → `/jj:squash`
- Tests mixed with implementation → `/jj:split test`
- Docs mixed with code → `/jj:split docs`
- End of session → Clean up the stack