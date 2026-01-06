# JJ Configuration

Jujutsu (jj) configuration managed via nix-darwin.

## Merge Tools

| Tool | Command | Use Case |
|------|---------|----------|
| `diffconflicts` | `jj resolve` | Default - nvim-based conflict resolution |
| `beads-merge` | `jj resolve --tool=beads-merge` | For `.beads/` files only |

### Beads Merge Tool

For conflicts in `.beads/issues.jsonl`, use:

```bash
jj resolve --tool=beads-merge
```

This uses `bd merge` which performs field-level 3-way merging instead of line-based, preserving concurrent updates to different fields of the same issue.

## Configuration Files

- `config.toml` - Main JJ configuration
- `conf.d/*.toml` - Per-context settings (work, nf-core, etc.)
