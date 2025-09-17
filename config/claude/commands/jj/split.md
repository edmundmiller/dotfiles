---
allowed-tools: Bash(jj split:*), Bash(jj status:*), Bash(jj log:*), Bash(jj diff:*)
description: Split changes into focused commits
model: claude-sonnet-4-20250514
---

## Current Status
!`jj status`
!`jj diff --summary`

## Split Workflow

I'll help you split your current changes into multiple focused commits.

### Options:

1. **Interactive split** - Choose which changes to separate
   ```bash
   jj split  # Opens hunk.nvim to select changes
   ```

2. **Split by files** - Separate specific files
   ```bash
   jj split path/to/file.js
   ```

### How splitting works:
- Selected changes move to a **new child commit**
- Remaining changes stay in the **current commit**
- You can then describe each commit appropriately

What would you like to split out?