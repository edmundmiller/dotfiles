---
allowed-tools: Bash(jj rebase*), Bash(jj status*), Bash(jj log*), Bash(jj branch list*), Bash(jj op log*)
description: Reorganize commits with automatic rebasing
---

## Current Structure
!`jj log -r ::@ --limit 5`

## Rebase Workflow

I'll help you reorganize your commits. In jj, rebasing is always safe and reversible.

### Common Operations:

1. **Update with main**
   ```bash
   jj rebase -d main
   ```

2. **Move current commit**
   ```bash
   jj rebase -d <destination>
   ```

3. **Reorganize history**
   ```bash
   jj rebase -r <commit> -d <new-parent>
   ```

### Key Benefits:
- **Always succeeds** - conflicts don't block rebasing
- **Automatic** - descendants follow automatically
- **Reversible** - use `jj undo` if needed

Where would you like to rebase your commits?