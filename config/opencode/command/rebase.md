---
description: Rebase current branch onto main with conflict awareness
---

Rebase the current branch onto the main branch with smart conflict handling.

1. First, check the current branch:

   ```
   git branch --show-current
   ```

2. Review changes in main since branching:

   ```
   git log HEAD..main --oneline
   ```

3. If there are relevant changes, summarize them briefly

4. Attempt the rebase:

   ```
   git rebase main
   ```

5. If conflicts occur:
   - List conflicting files with `git status`
   - For each conflict:
     - Show the conflict markers
     - Explain what both sides are trying to do
     - Suggest the appropriate resolution
   - After resolving, run `git add <file>` and `git rebase --continue`

6. If rebase succeeds, show the updated log:
   ```
   git log --oneline -5
   ```
