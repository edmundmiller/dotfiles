---
purpose: Non-interactive version control workflows and diff tooling preferences.
---

# Version Control

## Preferences

- **Diff policy:** prefer `diffs` over `git diff` (entity-level changes, better for agent review). Use native `git diff` only when `diffs` lacks needed flags/output.
- **Selective staging:** use `git hunks list` / `git hunks add <hunk-id>` — non-interactive, deterministic hunk IDs.
- **Dotfiles exception**: sibling layout (`../dotfiles.branch`) via `.envrc` override

## Non-interactive defaults (agents)

- Never use interactive git/editor flows in `bash` toolcalls (`git rebase -i`, `git add -p`, `git commit` without `-m`, `git mergetool`, `vim`, `less`, etc.)
- Use explicit non-interactive forms:
  - `git hunks list` + `git hunks add <hunk-id>` (not `git add -p`)
  - `git commit -m "..."` or `git commit --amend --no-edit`
  - `git commit --fixup <sha>` + `git rebase --autosquash <base>` for history cleanup
- If truly interactive flow needed, use `interactive_shell` (supervised) instead of `bash`

## Hunk ID Format

`file:@-old,len+new,len` — e.g. `README.md:@-1,3+1,5`

## Quick Reference

```bash
diffs                       # Semantic diff (default)
diffs --staged              # Semantic staged diff
git hunks list              # List hunks with stable IDs
git hunks add <hunk-id>     # Stage specific hunk
```

See `but`/`jut` skills for VCS workflows.
