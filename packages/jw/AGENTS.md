# jw - Agent Reference

## Purpose

`jw` manages jj workspaces for parallel agent execution. Each workspace is an isolated working copy sharing the same repository.

Uses `gum` for all interactive prompts, styled output, and spinners.

## Quick Reference

```bash
jwc agent-1      # Create + Claude (alias for jw switch -c -x claude)
jwo agent-1      # Create + OpenCode
jwl --full       # List with ahead counts
jw select        # Interactive workspace picker
jwm agent-1      # Merge to trunk
jwr agent-1      # Remove workspace
```

## Interactive Behaviors

When no args provided:
- `jw switch` → `gum filter` to select workspace
- `jw switch -c` → `gum input` for workspace name
- `jw remove` → `gum filter` to select workspace
- `jw merge` → `gum choose` for squash/rebase strategy

All commands support `--help` for detailed usage.

## File Structure

```
packages/jw/
├── jw           # Main entry, dispatches to lib/
├── lib/
│   ├── common.sh   # Gum wrappers: _error, _success, _spin, _header
│   ├── switch.sh   # cmd_switch, cmd_create, cmd_switch_help
│   ├── list.sh     # cmd_list (gum table), cmd_list_help
│   ├── select.sh   # cmd_select (gum filter), cmd_select_help
│   ├── remove.sh   # cmd_remove (gum confirm), cmd_remove_help
│   ├── merge.sh    # cmd_merge (gum choose), cmd_merge_help
│   ├── sync.sh     # cmd_sync (gum spin), cmd_sync_help
│   └── help.sh     # cmd_help (gum format markdown)
├── default.nix  # Nix package (includes gum dependency)
├── README.md    # User docs
└── AGENTS.md    # This file
```

## Key Functions in common.sh

| Function | Description |
|----------|-------------|
| `_error` | Red styled error message |
| `_warn` | Yellow styled warning |
| `_info` | Faint styled info |
| `_success` | Green styled success with checkmark |
| `_header` | Bold styled section header |
| `_spin` | Spinner wrapper for long operations |
| `_is_interactive` | Check if TTY available |
| `_require_tty` | Error if not interactive |

## Key Concepts

- **Workspace**: jj working copy with isolated @ commit
- **trunk()**: jj revset for main branch (auto-detected)
- **Workspace path**: Computed from `JW_WORKSPACE_PATH` pattern (default: `../{repo}--{name}`)

## Implementation Notes

- Uses `jj workspace list -T 'name ++ "\n"'` to get workspace names
- Paths computed from names (not stored by jj)
- Status checks use `--repository` flag to query other workspaces
- All counters use `$((var + 1))` syntax (not `((var++))`) for `set -e` compatibility
- JSON output (`--json`) has NO gum styling (machine-readable)

## Modifying

1. Edit files in `packages/jw/`
2. Run `hey rebuild`
3. Changes take effect immediately

## Testing

```bash
# Test in any jj repo
jw list
jw switch -c test-ws
jw list --full
jw select
jw merge --help
jw remove test-ws
```
