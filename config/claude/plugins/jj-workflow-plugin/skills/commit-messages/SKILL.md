---
name: Generating JJ Commit Messages
description: Generate descriptive commit messages for jujutsu repositories. Use when creating commits, describing changes, or when the user asks for commit message help. Follows conventional commit format and project conventions.
---

# Generating JJ Commit Messages

## Format

**Summary line:** `type(scope): brief description` (under 72 chars)

**Body (optional):** Blank line, then detailed explanation with bullets

**Footer (optional):**

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Conventional Commit Types

| Type         | Use Case           | Example                                    |
| ------------ | ------------------ | ------------------------------------------ |
| **feat**     | New features       | `feat(auth): implement JWT authentication` |
| **fix**      | Bug fixes          | `fix(login): correct password validation`  |
| **refactor** | Code restructuring | `refactor(auth): extract token helper`     |
| **docs**     | Documentation      | `docs(api): update auth examples`          |
| **test**     | Tests              | `test(auth): add login flow tests`         |
| **chore**    | Maintenance        | `chore(deps): upgrade to Python 3.12`      |
| **style**    | Formatting         | `style(auth): format with black`           |
| **perf**     | Performance        | `perf(db): optimize query with index`      |
| **ci**       | CI/CD              | `ci: add automated testing workflow`       |
| **build**    | Build system       | `build(nix): update flake inputs`          |

## Writing Guidelines

**Imperative mood:** "Add" not "Added" or "Adds"
**Be specific:** "Fix memory leak in data processor" not "Fix bug"
**Explain what and why:** "Refactor auth to support OAuth providers"
**One change per commit:** Suggest split if multiple unrelated changes

## Plan-to-Reality Pattern

Replace "plan:" commits with actual work done:

**Before:** `plan: Add user authentication system`

**After:**

```
feat(auth): implement JWT-based authentication

Add login endpoint with JWT token generation:
- POST /auth/login endpoint with email/password
- JWT token generation with 24h expiration
- Token validation middleware
```

## Generation Process

1. Analyze changes (`jj status`, `jj diff`)
2. Identify type (feat/fix/refactor/docs/test/chore)
3. Determine scope (component/area, or omit if project-wide)
4. Write summary: `type(scope): imperative verb + description` (<72 chars)
5. Add body if complex (bullets for multiple changes)
6. Include Claude Code footer

## File Pattern Auto-Generation

**Tests:** `test(component): add unit tests for feature`
**Docs:** `docs(section): update documentation`
**Config:** `chore(config): update configuration`
**Mixed:** Describe primary purpose, list secondary in body

## Match Project Style

Check recent commits for conventions:

```bash
jj log -r 'ancestors(@, 10)' -T 'concat(change_id.short(), ": ", description)' --no-graph
```

Observe: scope naming, detail level, body formatting, emoji usage, footer pattern

## When to Activate

**Suggest message when:**

- User completes substantial work
- Changes ready to describe
- Plan commit needs updating
- User asks for help

**Don't auto-generate when:**

- User provides explicit message
- Work still in progress
- Changes minimal/unclear
