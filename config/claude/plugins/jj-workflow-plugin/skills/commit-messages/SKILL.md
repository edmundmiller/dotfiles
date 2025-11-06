---
name: Generating JJ Commit Messages
description: Generate descriptive commit messages for jujutsu repositories. Use when creating commits, describing changes, or when the user asks for commit message help. Follows conventional commit format and project conventions.
allowed-tools: Bash(jj status:*), Bash(jj diff:*), Bash(jj log:*)
---

# Generating JJ Commit Messages

## Format

**Summary line:** `type(scope): brief description` (under 72 chars)

**Body (optional):** Blank line, then detailed explanation with bullets

**Footer:**

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

## Quick Guidelines

- Use imperative mood: "Add" not "Added"
- Be specific: "Fix memory leak in parser" not "Fix bug"
- Scope is optional but helpful: `feat(auth): ...` or just `feat: ...`
- Keep summary under 72 characters
- Add body with bullets for complex changes
