---
allowed-tools: Bash(jj squash*), Bash(jj status*), Bash(jj log*), Bash(jj diff*), Bash(jj show*)
description: Complete work via squash workflow
---

## Current Status
!`jj status`
!`jj log -r ::@ --limit 3 --no-graph`

## Squash Workflow

The squash workflow in jj: **Describe → New → Implement → Squash**

I'll help you complete your current work by squashing changes into the parent commit.

### What would you like to do?

1. **Quick squash** - Move all current changes into parent
   ```bash
   jj squash
   ```

2. **Interactive squash** - Choose specific changes
   ```bash
   jj squash -i  # Opens editor to select hunks
   ```

3. **Squash with message** - Update commit message while squashing
   ```bash
   jj squash -m "feat: completed feature"
   ```

### Current changes to squash:
!`jj diff --summary`

Let me know if you want to:
- Squash everything into the parent commit
- Select specific changes interactively
- Update the commit message first