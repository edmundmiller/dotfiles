# QMD Freshness

Freshness is derived from git, not from file mtimes.

## Marker fields used

- `last_indexed_commit`
- `last_indexed_at`

## Check

The extension compares the indexed commit against `HEAD` with a markdown-only diff.

Conceptually:

```bash
git diff --name-only --diff-filter=ACMR <last_indexed_commit>..HEAD -- ':(glob)**/*.md'
```

## Results

- **fresh** — no markdown changes since the indexed commit
- **stale** — markdown files changed; includes count and paths
- **unknown** — non-git repo, missing commit, or diff failure

## Footer behavior

- indexed + fresh -> `qmd: indexed ✓`
- indexed + stale -> `qmd: indexed · N stale`
- indexed + unknown -> `qmd: indexed · freshness unknown`
- not indexed -> silent
- QMD unavailable -> silent
