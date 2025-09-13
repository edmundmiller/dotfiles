---
allowed-tools: Bash(jj op log*), Bash(jj op restore*), Bash(jj undo*), Bash(jj status*), Bash(jj log*)
description: Safety net - undo any operation
---

## Recent Operations
!`jj op log --limit 5`

## Safety Net

Everything in jj is undoable! I'll help you recover from any mistake.

### Quick Recovery:

1. **Undo last operation**
   ```bash
   jj undo
   ```

2. **Restore to specific point**
   ```bash
   jj op restore <operation-id>
   ```

3. **View more history**
   ```bash
   jj op log --limit 10
   ```

### What went wrong?
- Accidental squash?
- Bad split?
- Wrong rebase?
- Just want to go back?

Tell me what happened and I'll help you fix it. Remember: **you can always undo an undo!**