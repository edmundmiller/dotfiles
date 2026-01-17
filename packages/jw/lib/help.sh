# jw help command

cmd_help() {
    gum format <<'EOF'
# jw - JJ Workspace Management

> Manage jj workspaces for parallel AI agents

## Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `switch` | `s` | Switch to workspace (creates with `-c`) |
| `create` | `c` | Create new workspace |
| `list` | `ls`, `l` | List all workspaces with status |
| `select` | | Interactive workspace picker |
| `remove` | `rm`, `r` | Remove a workspace |
| `merge` | `m` | Merge workspace changes to trunk |
| `sync` | | Sync workspace with trunk (rebase) |

## Quick Start

```bash
# Create workspace and start Claude
jw switch -c -x claude agent-1

# In another terminal
jw switch -c -x opencode agent-2

# Check status
jw list --full

# Merge when done
jw merge agent-1
jw remove agent-1
```

## Interactive Features

**No args?** Many commands become interactive:
- `jw switch` — Select from existing workspaces
- `jw switch -c` — Prompt for workspace name
- `jw remove` — Select workspace to remove
- `jw merge` — Choose rebase or squash strategy

## Configuration

Set `JW_WORKSPACE_PATH` for custom workspace locations:

```bash
export JW_WORKSPACE_PATH='../{repo}--{name}'
```

Supports `{repo}` and `{name}` placeholders.

---

Run `jw <command> --help` for detailed command help.
EOF
}
