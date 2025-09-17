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

This project uses jujutsu (jj), a Git-compatible VCS with a more intuitive model. Think in terms of **moving changes between commits** rather than staging/unstaging.

### Core Workflows

**Squash Workflow** ⭐ **RECOMMENDED** (Describe → New → Implement → Squash):
1. `jj describe -m "what you're doing"` - Describe current work
2. `jj new` - Create empty change for new work
3. Make changes
4. `jj squash` - Move changes into parent commit

**Edit Workflow** 🔧 **ADVANCED** (Edit any commit directly):
- `jj edit <change-id>` - Edit any previous commit
- Changes automatically rebase
- No checkout dance needed

### Essential Commands

- `jj status` - Show current state
- `jj log` - Browse commit history
- `jj diff` - See current changes
- `jj new` - Start new work
- `jj describe -m "msg"` - Write commit message
- `jj squash` - Complete work (move to parent)
- `jj split` - Split mixed changes
- `jj undo` - Undo last operation
- `jj op log` - View operation history
- `jj op restore <id>` - Time-travel to any point

### Key Principles

- **Everything is undoable** - Use `jj op log` and `jj undo`/`jj op restore`
- **No staging area** - Changes are always in commits, just move them around
- **Automatic rebasing** - Edit any commit, descendants follow automatically
- **Conflicts don't block** - Conflicts stored in commits, not working directory

### Claude Commands (Tutorial-Based)

**Workflow Commands:**
- `@squash-workflow` - Complete guided squash workflow with intelligent state detection
- `@edit-workflow` - Advanced multi-commit workflow for complex features
- `@new` - Start new work with workflow recommendations
- `@status` - Enhanced status with workflow context and next-action suggestions

**Core Operations:**
- `@squash` - Complete current work (final step of squash workflow)
- `@describe` - Write commit messages (emphasizes describing intent first)
- `@split` - Split mixed changes into focused commits
- `@navigate` - Move between and edit changes in history
- `@abandon` - Safely discard unwanted changes
- `@undo` - Safety net (everything is undoable)
- `@rebase` - Reorganize commits (conflicts don't block)

**Quick Examples:**
```bash
@squash-workflow "feat: implement user auth"  # Guided workflow
@squash-workflow auto                         # Auto-detect next step
@status                                       # Get workflow recommendations
@undo                                         # Fix any mistakes
```

When working with jj, use `jj status` and `jj log` frequently to understand state.