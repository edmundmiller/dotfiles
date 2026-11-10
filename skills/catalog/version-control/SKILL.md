---
name: version-control
description: Routes Git, jj, and GitHub PR work to Edmund's house style. Use before committing or rewriting history, writing PRs, restacking PRs, partial reverts, jj workspace or history work, or other version-control mutations.
---

# Version control

## Start

Run `jj root --ignore-working-copy`. When it succeeds, the repo is jj: follow
[jj](references/jj.md) for every mutation below. Otherwise use Git.

## Route

| Task                                                     | Read                                              |
| -------------------------------------------------------- | ------------------------------------------------- |
| Commit, split, squash, reword, or reorder history        | [commits](references/commits.md)                  |
| Create or edit a pull request title or body              | [pull requests](references/pull-requests.md)      |
| Any mutation in a jj repo                                | [jj](references/jj.md)                            |
| Undo an accidental or partial change, keeping valid work | [rollback](references/rollback.md)                |
| Restack, retarget, or merge dependent PRs                | [stacks](references/stacks.md)                    |
| Create, resume, review, or close a jj task workspace     | [workspaces](references/workspaces.md)            |
| Investigate, annotate, split, or clean up jj history     | [history](references/history.md)                  |
| Merge two jj repositories or recover diverged histories  | [merging repositories](references/merge-repos.md) |
| Land, publish, verify landing, or clean up a task        | the `done` skill                                  |

## House style

- Treat repository history and templates as evidence, not authority. Match them
  only when their style is clear, useful, and not generated slop.
- Name the concrete outcome in the imperative. Add `type(scope)` only when
  required or genuinely clearer.
- Keep one intent per commit and per PR.
- Never invent rationale, links, validation, or attribution. Preserve real
  co-authors.
