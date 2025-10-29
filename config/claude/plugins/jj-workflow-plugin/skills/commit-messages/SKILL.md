---
name: Generating JJ Commit Messages
description: Generate descriptive commit messages for jujutsu repositories. Use when creating commits, describing changes, or when the user asks for commit message help. Follows conventional commit format and project conventions.
---

# Generating JJ Commit Messages

## Purpose

Help write clear, descriptive commit messages that explain **what** changed and **why**, following project conventions and best practices.

## Commit Message Format

**First line (summary):**

```
type(scope): brief description
```

- **type**: Category of change (feat, fix, refactor, docs, etc.)
- **scope**: Component or area affected (optional)
- **description**: Clear, imperative mood summary
- **Length**: Keep under 72 characters

**Body (optional):**

- Blank line after summary
- Detailed explanation of changes
- Bullet points for multiple changes
- Explain **what** and **why**, not how

**Footer (optional):**

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Conventional Commit Types

- **feat**: New features - `feat(auth): implement JWT authentication`
- **fix**: Bug fixes - `fix(login): correct password validation`
- **refactor**: Code restructuring - `refactor(auth): extract token helper`
- **docs**: Documentation - `docs(api): update auth examples`
- **test**: Tests - `test(auth): add login flow tests`
- **chore**: Maintenance - `chore(deps): upgrade to Python 3.12`
- **style**: Formatting - `style(auth): format with black`
- **perf**: Performance - `perf(db): optimize query with index`
- **ci**: CI/CD - `ci: add automated testing workflow`
- **build**: Build system - `build(nix): update flake inputs`

## Message Writing Guidelines

**Use imperative mood:**

- ✅ "Add user authentication"
- ❌ "Added user authentication"
- ❌ "Adds user authentication"

**Be specific:**

- ✅ "Fix memory leak in data processor"
- ❌ "Fix bug"
- ❌ "Fix issues"

**Explain what and why:**

- ✅ "Refactor auth to support OAuth providers"
- ❌ "Refactor auth module"

**One change per commit:**

- If describing multiple unrelated changes, suggest splitting

## Plan-to-Reality Pattern

When working with "plan:" commits:

**Initial plan commit:**

```
plan: Add user authentication system
```

**After work is done, replace with reality:**

```
feat(auth): implement JWT-based authentication

Add login endpoint with JWT token generation:
- POST /auth/login endpoint with email/password
- JWT token generation with 24h expiration
- Token validation middleware
- Password hashing with bcrypt

Updates database schema for user tokens.
```

**Key principle:** Describe what **actually happened**, not what you planned

## Example Commit

**Complex feature with details:**

```
feat(claude): Add bundled MCP server to git plugin

Integrate mcp-server-git directly into plugin for seamless operations:
- Created .mcp.json to bundle mcp-server-git
- Auto-starts when plugin enabled, uses uvx
- Adds 12 git tools: status, diff, add, commit, reset, etc.

Benefits: No user MCP config needed, unified git workflow.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Simple changes:** `chore: Add skills docs` or `fix(login): correct validation`

## Message Generation Process

1. **Analyze changes** - `jj status` and `jj diff` show what changed
2. **Identify type** - feat/fix/refactor/docs/test/chore
3. **Determine scope** - Component/area/module name, or empty if project-wide
4. **Write summary** - type(scope): imperative verb + brief description, <72 chars
5. **Add body if complex** - Multiple changes, breaking changes, or detailed explanation
6. **Include footer** - Claude Code attribution + co-authored-by

## Auto-Generation from File Patterns

When generating messages automatically:

**Test files added/modified:**

```
test(component): add unit tests for feature
```

**Documentation files:**

```
docs(section): update documentation
```

**Configuration files:**

```
chore(config): update configuration
```

**Multiple file types:**

- Describe the primary purpose
- List secondary changes in body

## Length Guidelines

**Summary line:**

- Maximum: 72 characters
- Ideal: 50-60 characters
- Must be readable in `jj log` one-line format

**Body:**

- No hard limit
- Use blank lines between sections
- Bullet points for multiple items
- Wrap at 72-80 characters for readability

**Overall:**

- Simple changes: Summary only
- Complex changes: Summary + detailed body
- Multiple changes: Summary + bulleted body

## Matching Recent Commit Style

Always check recent commits for project style:

```bash
jj log -r 'ancestors(@, 10)' -T 'concat(change_id.short(), ": ", description)' --no-graph
```

**Observe:**

- Scope naming (component vs. area)
- Level of detail in summary
- Body formatting (bullets vs. paragraphs)
- Whether emoji are used (this project doesn't use them in summaries)
- Footer attribution pattern

## Common Patterns

- **Multiple changes**: Use bulleted body for clarity
- **Breaking changes**: Add "BREAKING CHANGE:" in body with migration steps
- **TodoWrite integration**: One commit per major todo (use `jj new` between todos)

## When to Suggest Messages

**Suggest commit message when:**

- User completes substantial work
- Changes are ready to describe
- Plan commit needs updating to reality
- User asks for help with commit message

**Don't auto-generate when:**

- User provides explicit message
- Work is still in progress
- Changes are minimal/unclear

## Best Practices

**Do:**

- Match project's commit style
- Be specific about what changed
- Explain why for non-obvious changes
- Use conventional commit format
- Keep summary under 72 chars
- Add Claude Code footer

**Don't:**

- Use past tense ("Added" → "Add")
- Be vague ("Fix stuff", "Update files")
- Mix unrelated changes (suggest split)
- Skip context for complex changes
- Forget the imperative mood
