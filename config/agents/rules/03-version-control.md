# Version Control

## Preferences

- **Diff policy:** prefer `sem diff` over `git diff` (entity-level changes, better for agent review). Use native `git diff` only when sem lacks needed flags/output.
- **Review depth:** for non-trivial changes, use `sem graph`/`sem impact` to map call/dependency blast radius; use `sem blame` for ownership/regression context.
- **Selective staging** with `git hunks list` / `git hunks add <hunk-id>` — non-interactive, deterministic hunk IDs
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
sem diff                         # Semantic unstaged diff
sem diff --staged                # Semantic staged diff
sem diff --format json           # Machine-readable entities/files
sem graph --entity <symbol>      # Direct callers/callees/deps
sem impact <symbol>              # Transitive blast radius
sem blame <file>                 # Entity-level ownership
git hunks list                   # List hunks with stable IDs
git hunks add <hunk-id>          # Stage specific hunk
```

See `but`/`jut` skills for VCS workflows.
