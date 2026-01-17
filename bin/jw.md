# jw - JJ Workspace Management

A CLI tool for managing Jujutsu (jj) workspaces, inspired by [worktrunk](https://github.com/max-sixty/worktrunk) for git worktrees.

Designed for running AI agents (Claude, OpenCode) in parallel using jj workspaces.

## Quick Start

```bash
# Create and launch Claude in a new workspace
jw switch -c -x claude agent-1

# In another terminal, start another agent
jw switch -c -x opencode agent-2

# Check status of all workspaces
jw list --full

# Merge completed work
jw merge agent-1

# Clean up
jw remove agent-1
```

## Commands

| Command | Description |
|---------|-------------|
| `jw switch <name>` | Switch to existing workspace |
| `jw switch -c <name>` | Create and switch to workspace |
| `jw switch -c -x <cmd> <name>` | Create, switch, and execute command |
| `jw list` | List workspaces with status |
| `jw list --full` | Include ahead counts |
| `jw list --json` | Output as JSON |
| `jw remove [name]` | Remove workspace (current if no name) |
| `jw merge [name]` | Merge workspace to trunk |
| `jw sync [name]` | Sync workspace with trunk |

## Aliases

Add to your shell config (already included in dotfiles):

```bash
alias jws='jw switch'       # Switch to workspace
alias jwl='jw list'         # List workspaces
alias jwr='jw remove'       # Remove workspace
alias jwm='jw merge'        # Merge to trunk
alias jwc='jw switch -c -x claude'    # Create + Claude
alias jwo='jw switch -c -x opencode'  # Create + OpenCode
```

## Comparison with worktrunk (wt)

| Task | jw (jj workspaces) | wt (git worktrees) |
|------|--------------------|--------------------|
| Create + Claude | `jwc agent-1` | `wt switch -c -x claude agent-1` |
| List with status | `jwl --full` | `wt list --full` |
| Merge to main | `jwm agent-1` | `wt merge agent-1` |
| Remove | `jwr agent-1` | `wt remove agent-1` |

## Key Differences from Git Worktrees

- **No branches needed**: jj uses changes/revisions, not branches
- **First-class conflicts**: jj handles conflicts natively
- **Simpler merging**: Just rebase onto trunk
- **Undo everything**: jj operation log provides complete history

## Configuration

Set `JW_WORKSPACE_PATH` to customize workspace locations:

```bash
# Default (sibling directories)
export JW_WORKSPACE_PATH='../{repo}--{name}'

# Inside .jj-workspaces (like workflow tool)
export JW_WORKSPACE_PATH='.jj-workspaces/{name}'

# Absolute path
export JW_WORKSPACE_PATH='~/workspaces/{repo}/{name}'
```

Supports placeholders:
- `{repo}` - Repository name
- `{name}` - Workspace name

## Agent Workflow Example

```bash
# Terminal 1: Main development
cd ~/src/myproject

# Terminal 2: Start agent for feature work
jwc feature-auth

# Terminal 3: Start agent for refactoring
jwo refactor-db

# Check all agents
jwl --full
# WORKSPACE       STATUS       AHEAD    PATH
# *default        ● clean               ~/src/myproject
#  feature-auth   ● dirty      ↑2      ~/src/myproject--feature-auth
#  refactor-db    ● dirty      ↑1      ~/src/myproject--refactor-db

# When agent finishes, merge and clean up
jwm feature-auth
jwr feature-auth
```

## See Also

- [worktrunk](https://worktrunk.dev) - Git worktree management for agents
- [jj workspaces](https://martinvonz.github.io/jj/latest/working-copy/#workspaces) - Official docs
- [poucet/workflow](https://github.com/poucet/workflow) - Similar jj workflow tool
