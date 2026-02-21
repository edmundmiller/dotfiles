# Version Control

## Preferences

- **Bare repo layout** for all new repos (`gcl <url>`, then `wt switch -c main`)
- **Selective staging** with `git hunks list` / `git hunks add <hunk-id>` — non-interactive, deterministic hunk IDs
- **Dotfiles exception**: sibling layout (`../dotfiles.branch`) via `.envrc` override

## Hunk ID Format

`file:@-old,len+new,len` — e.g. `README.md:@-1,3+1,5`

## Quick Reference

```bash
wt switch -c <branch>       # Create worktree + branch
wt list                     # List worktrees with status
wt merge                    # Squash-merge, clean up
git hunks list              # List hunks with stable IDs
git hunks add <hunk-id>     # Stage specific hunk
```

See `but`/`jut` skills for VCS workflows. See `wt --help` for worktree management.
