---
name: writing-git-commits
description: Write clean, atomic conventional commits from staged or uncommitted changes. Use when asked to commit, generate commit messages, or clean up git history.
---

# Writing Git Commits

## Workflow

1. **Inspect** — `sem diff --staged` (staged) and `sem diff` (unstaged); fallback to `git diff --stat` when raw line stats required
2. **Group** — cluster related changes into atomic commits (one logical change per commit)
3. **Order** — commit foundational changes first (deps, config, types), then features, then tests
4. **Write** — craft each message per the format below
5. **Stage & commit** — `git add -p` or `git add <paths>` then `git commit -m "..."`

## Message Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

| Type       | When                                    |
| ---------- | --------------------------------------- |
| `feat`     | New feature or capability               |
| `fix`      | Bug fix                                 |
| `refactor` | Code change that neither fixes nor adds |
| `docs`     | Documentation only                      |
| `test`     | Adding or updating tests                |
| `chore`    | Build, CI, deps, tooling                |
| `style`    | Formatting, whitespace, semicolons      |
| `perf`     | Performance improvement                 |

### Rules

- **Subject**: imperative mood, lowercase, no period, ≤72 chars
- **Scope**: optional, the module/area affected (e.g., `auth`, `pi`, `nix`)
- **Body**: wrap at 72 chars, explain _what_ and _why_ (not _how_)
- **Footer**: `Closes #123`, `BREAKING CHANGE: ...`
- **Atomic**: each commit compiles/passes independently
- **No mixed concerns**: don't combine a bugfix with a refactor

### Examples

```
feat(pi): add diff-renderer extension

chore: update flake inputs

fix(auth): prevent token refresh race condition

Tokens were being refreshed concurrently, causing 401s for
in-flight requests. Added a mutex around the refresh call.

Closes #42

refactor(shell): extract zsh plugin config to module
```

## Grouping Heuristics

- Same file touched for different reasons → separate commits
- Multiple files for one feature → single commit
- Formatting/whitespace mixed with logic → split them
- Dependency updates → own commit (`chore(deps): ...`)
- Generated files (lockfiles, schemas) → commit with the change that caused them
