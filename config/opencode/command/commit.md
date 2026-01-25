---
description: Generate commit message and commit staged changes
---

Review the staged changes and generate a concise commit message.

1. Run `git diff --cached` to see staged changes
2. Analyze the changes and write a commit message that:
   - Summarizes the "why" not the "what"
   - Uses imperative mood (e.g., "Add feature" not "Added feature")
   - Is 1-2 sentences max
   - Follows the repository's existing commit style
3. Run `git commit -m "<message>"`
4. Show the commit hash and summary

If nothing is staged, check `git status` and suggest what to stage.
