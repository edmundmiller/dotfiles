# Version Control

## Preferences

- **Diff policy:** prefer `sem diff` over `git diff` (entity-level changes, better for agent review). Use native `git diff` only when sem lacks needed flags/output.
- **Selective staging** with `git hunks list` / `git hunks add <hunk-id>` — non-interactive, deterministic hunk IDs
- **Dotfiles exception**: sibling layout (`../dotfiles.branch`) via `.envrc` override

## Hunk ID Format

`file:@-old,len+new,len` — e.g. `README.md:@-1,3+1,5`

## Quick Reference

```bash
sem diff                    # Semantic diff (default)
sem diff --staged           # Semantic staged diff
git hunks list              # List hunks with stable IDs
git hunks add <hunk-id>     # Stage specific hunk
```

See `but`/`jut` skills for VCS workflows.
