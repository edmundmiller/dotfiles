# Commits

## Workflow

1. Inspect: `diffs --staged` and `diffs`; fall back to `git diff --stat` for raw line stats.
2. Group related changes by intent.
3. Order foundations first (deps, config, types), then features, then tests.
4. Write each message in the format below.
5. Stage and commit: `git hunks list`, `git hunks add <hunk-id>` (or `git add <paths>`), then `git commit -m "..."`. In jj, see [jj](jj.md) instead.

## Message

```
[type(scope): ]<imperative subject naming the outcome>

[body: only why, tradeoffs, surprising constraints, exact evidence, or attribution]
```

- Subject: imperative, no period, ≤72 characters.
- Type, when used: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`.
- Body: wrap at 72; say why, not how. Footers such as `Closes #123` or `BREAKING CHANGE:` only when true.
- Remove WIP, merge-sync, "try", "hack", "polish", and vague "update" messages before review.

## Grouping

- Same file changed for different reasons → separate commits.
- Many files for one change → one commit.
- Formatting mixed with logic → split.
- Dependency updates → their own commit.
- Generated files (lockfiles, schemas) → with the change that caused them.
- Each commit should build and pass on its own.
