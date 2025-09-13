---
allowed-tools: Bash(jj describe*), Bash(jj log*), Bash(jj status*), Bash(jj show*)
description: Write clear commit messages
---

## Current Commit
!`jj log -r @ --no-graph`

## Describe Your Changes

I'll help you write a clear commit message.

### Quick Options:

1. **Simple message**
   ```bash
   jj describe -m "your message"
   ```

2. **Conventional commit**
   ```bash
   jj describe -m "type: description"
   ```
   Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

3. **Edit in editor**
   ```bash
   jj describe  # Opens your editor
   ```

### Current changes:
!`jj diff --summary`

What type of change is this? I'll help you write an appropriate message.