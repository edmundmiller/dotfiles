---
purpose: Non-interactive version control workflows and diff tooling preferences.
rule_id: AGENT-03
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-03.md
---

# Version Control

## Preferences

- **Diff policy:** prefer `sem diff` over `git diff` (entity-level changes, better for agent review). Use native `git diff` only when sem lacks needed flags/output.
- **Selective staging:** use `git hunks list` / `git hunks add <hunk-id>` — non-interactive, deterministic hunk IDs.
- **Dotfiles exception**: sibling layout (`../dotfiles.branch`) via `.envrc` override
- **Commit scope:** before committing, compare staged paths with the current request. “Commit/push” authorizes only those paths; if they are already landed and only unrelated paths remain, report that state instead of touching them.
- **Hook validation:** do not run `prek` manually during routine validation. Let commit or push invoke its hooks; run `prek` directly only when configuring/debugging hooks or when explicitly requested.


## Herdr + jj + OMP

- Herdr owns task-workspace creation. Use `prefix+a` for one stable task-named jj workspace; the new workspace opens with OMP focused.
- In a Herdr-created jj workspace, record the task with `hey agent-start` without `--workspace`; outside Herdr, in a jj repository, use `using-jj-workspaces` to create and record the workspace.
- Detect the live backend with `jj root --ignore-working-copy`. Use jj commands in a jj repository; never initialize jj inside a Codex Desktop Git worktree.
- Hunk requires a Git checkout. Resolve the root with `git rev-parse --show-toplevel`; a Herdr workspace outside Git intentionally contains only OMP.
- Keep one task bookmark per workspace. Review with Hunk from a Git root or `jj diff --git -r @` in pure jj; use `done` for publication and cleanup, and `prefix+g` only for intentionally Git-only work.

## Non-interactive defaults (agents)

- Never use interactive git/editor flows in `bash` toolcalls (`git rebase -i`, `git add -p`, `git commit` without `-m`, `git mergetool`, `vim`, `less`, etc.)
- Use explicit non-interactive forms:
  - `git hunks list` + `git hunks add <hunk-id>` (not `git add -p`)
  - `git commit -m "..."` or `git commit --amend --no-edit`
  - `git commit --fixup <sha>` + `git rebase --autosquash <base>` for history cleanup
- If an interactive flow is truly required, use the runtime's supervised interactive shell; otherwise ask the user to perform it.

## Hunk ID Format

`file:@-old,len+new,len` — e.g. `README.md:@-1,3+1,5`

## Quick Reference

```bash
sem diff                    # Semantic diff (default)
sem diff --staged           # Semantic staged diff
git hunks list              # List hunks with stable IDs
git hunks add <hunk-id>     # Stage specific hunk
```

See `writing-git-commits` for Git commits and `herdr-jj-workflow` for task-scoped jj workspaces.
