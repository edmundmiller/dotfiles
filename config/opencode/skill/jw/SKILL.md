---
name: jw
description: "JJ Workspace management for parallel agents. Use when creating workspaces, switching between them, listing status, or merging work to trunk."
triggers:
  - "jj workspace"
  - "jw"
  - "parallel agent"
  - "create workspace"
  - "switch workspace"
  - "list workspaces"
  - "merge workspace"
---

# jw - JJ Workspace Management

`jw` is a CLI for managing Jujutsu (jj) workspaces, designed for running AI agents in parallel.

## Quick Reference

| Task | Command |
|------|---------|
| Create + Claude | `jw switch -c -x claude agent-1` or `jwc agent-1` |
| Create + OpenCode | `jw switch -c -x opencode agent-1` or `jwo agent-1` |
| List all | `jw list` or `jwl` |
| List with ahead counts | `jw list --full` or `jwl --full` |
| Switch to workspace | `jw switch name` or `jws name` |
| Merge to trunk | `jw merge name` or `jwm name` |
| Remove workspace | `jw remove name` or `jwr name` |

## Aliases

```bash
jws='jw switch'       # Switch to workspace
jwl='jw list'         # List workspaces
jwr='jw remove'       # Remove workspace
jwm='jw merge'        # Merge to trunk
jwc='jw switch -c -x claude'    # Create + Claude
jwo='jw switch -c -x opencode'  # Create + OpenCode
```

## Agent Workflow

```bash
# Start multiple agents in parallel
jwc agent-1      # Terminal 1: Create + Claude
jwc agent-2      # Terminal 2: Create + Claude
jwo agent-3      # Terminal 3: Create + OpenCode

# Check status
jwl --full
# WORKSPACE       STATUS       AHEAD    PATH
# *default        ● clean               ~/src/myproject
#  agent-1        ● dirty      ↑2      ~/src/myproject--agent-1
#  agent-2        ● dirty      ↑1      ~/src/myproject--agent-2

# When agent finishes
jwm agent-1      # Merge to trunk
jwr agent-1      # Clean up
```

## Workspace Paths

Default: `../{repo}--{name}` (sibling directories)

Example for `~/src/myproject` with workspace `agent-1`:
- Creates: `~/src/myproject--agent-1`

Override with `JW_WORKSPACE_PATH`:
```bash
export JW_WORKSPACE_PATH='.jj-workspaces/{name}'  # Inside repo
```

## Key Differences from Git Worktrees

- **No branches needed**: jj uses changes/revisions
- **First-class conflicts**: jj handles conflicts natively  
- **Undo everything**: jj operation log provides complete history
- **Simpler**: Just rebase onto trunk()

## Commands

### switch
```bash
jw switch name           # Switch to existing workspace
jw switch -c name        # Create and switch
jw switch -c -x claude   # Create, switch, start Claude
```

### list
```bash
jw list          # Basic status (clean/dirty)
jw list --full   # Include ahead counts
jw list --json   # JSON output for scripting
```

### merge
```bash
jw merge              # Merge current workspace to trunk
jw merge name         # Merge specific workspace
jw merge --squash     # Squash all commits
```

### sync
```bash
jw sync         # Rebase current workspace onto trunk
jw sync name    # Rebase specific workspace
```

### remove
```bash
jw remove          # Remove current workspace
jw remove name     # Remove specific workspace
jw remove -f       # Force (ignore uncommitted changes)
```
