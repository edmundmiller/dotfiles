# jw - Agent Reference

## Purpose

`jw` manages jj workspaces for parallel agent execution. Each workspace is an isolated working copy sharing the same repository.

## Quick Reference

```bash
jwc agent-1      # Create + Claude (alias for jw switch -c -x claude)
jwo agent-1      # Create + OpenCode
jwl --full       # List with ahead counts
jwm agent-1      # Merge to trunk
jwr agent-1      # Remove workspace
```

## File Structure

```
packages/jw/
├── jw           # Main entry point, dispatches to lib/
├── lib/
│   ├── common.sh   # Utilities: colors, _repo_root, _workspace_path, etc.
│   ├── switch.sh   # cmd_switch, cmd_create
│   ├── list.sh     # cmd_list, _list_json
│   ├── remove.sh   # cmd_remove
│   ├── merge.sh    # cmd_merge
│   └── sync.sh     # cmd_sync
├── default.nix  # Nix package
├── README.md    # User docs
└── AGENTS.md    # This file
```

## Key Concepts

- **Workspace**: jj working copy with isolated @ commit
- **trunk()**: jj revset for main branch (auto-detected)
- **Workspace path**: Computed from `JW_WORKSPACE_PATH` pattern (default: `../{repo}--{name}`)

## Implementation Notes

- Uses `jj workspace list -T 'name ++ "\n"'` to get workspace names
- Paths computed from names (not stored by jj)
- Status checks use `--repository` flag to query other workspaces
- All counters use `$((var + 1))` syntax (not `((var++))`) for `set -e` compatibility

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
jw remove test-ws
```
