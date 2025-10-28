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

**feat**: New features or capabilities

```
feat(auth): implement JWT-based authentication
feat(api): add user profile endpoint
```

**fix**: Bug fixes

```
fix(login): correct password validation logic
fix(api): handle null response in user fetch
```

**refactor**: Code restructuring without behavior change

```
refactor(auth): extract token validation to helper
refactor(editors): abstract file associations into shared module
```

**docs**: Documentation changes

```
docs(api): update authentication endpoint examples
docs(readme): add installation instructions
```

**test**: Adding or modifying tests

```
test(auth): add unit tests for login flow
test(api): add integration tests for user endpoints
```

**chore**: Maintenance tasks, dependencies, build changes

```
chore: update dependencies
chore(deps): upgrade to Python 3.12
```

**style**: Code style, formatting (no logic changes)

```
style(auth): format with black
style: apply prettier to all JS files
```

**perf**: Performance improvements

```
perf(db): optimize user query with index
perf(api): cache frequent user lookups
```

**ci**: CI/CD configuration changes

```
ci: add automated testing workflow
ci(actions): update deployment pipeline
```

**build**: Build system or external dependencies

```
build: update webpack config
build(nix): update flake inputs
```

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

## Examples from This Project

### Example 1: Feature with Details

```
feat(claude): Add bundled MCP server to git plugin

Integrate mcp-server-git directly into the git plugin for seamless git
operations:

**MCP Integration:**
- Created .mcp.json to bundle mcp-server-git
- MCP server starts automatically when plugin is enabled
- Uses uvx to run mcp-server-git without additional setup

**12 New Git Tools:**
Status & Diff:
- git_status, git_diff_unstaged, git_diff_staged, git_diff

Commit Operations:
- git_add, git_commit, git_reset

**Benefits:**
- No user MCP configuration needed
- Slash commands for complex workflows
- MCP tools for quick, direct operations

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Example 2: Refactoring

```
refactor(editors): Abstract file associations into shared module

- Create modules/editors/file-associations.nix for reusable duti configuration
- Remove duplicate duti setup from hosts/mactraitorpro and hosts/seqeratop
- Add file-associations module to both hosts with zed as default
- Supports easy editor switching (zed, neovide, vscode, or custom bundle ID)
- Reduces code duplication by ~180 lines across host configs
```

### Example 3: Fix with Context

```
fix(claude): Rename plugin to 'jj' for cleaner namespace

User requested shorter plugin name for better UX:

**Changed:**
- plugin.json: "jj-workflow-plugin" → "jj"
- marketplace.json: "jj-workflow-plugin" → "jj"

**Kept:**
- Directory name stays as jj-workflow-plugin (implementation detail)
- All functionality and commands unchanged

**Benefits:**
- Cleaner plugin identifier in marketplace
- Simpler plugin name for users
- Commands show as /jj:* instead of /jj-workflow-plugin:*

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Example 4: Simple Change

```
chore: Add skills docs
```

## Message Generation Process

**Note:** The `/jj:commit` command automatically tracks new untracked files before committing, so all files in your working copy changes will be included.

**1. Analyze changes:**

```bash
jj status        # See what files changed
jj diff          # Review actual changes
```

**2. Identify change type:**

- New functionality? → `feat`
- Bug fix? → `fix`
- Restructuring? → `refactor`
- Documentation? → `docs`
- Tests? → `test`
- Maintenance? → `chore`

**3. Determine scope:**

- Component name (auth, api, ui)
- Area of codebase (claude, jj, nvim)
- Module name (editors, shell)
- Leave empty if project-wide

**4. Write summary:**

- Start with type(scope):
- Imperative mood verb
- Brief but specific
- Under 72 characters

**5. Add body if needed:**

- Complex changes need explanation
- Multiple related changes need bullets
- Breaking changes need details
- Simple changes can skip body

**6. Include footer:**

- Always add Claude Code attribution
- Co-authored-by line

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

### Multiple Related Changes

**Use bullets for clarity:**

```
refactor(module): improve error handling

- Extract error handling to dedicated helper
- Add specific error types for different cases
- Update tests to verify error messages
- Add logging for debugging
```

### Breaking Changes

**Highlight in body:**

```
feat(api): redesign authentication endpoint

BREAKING CHANGE: /auth/login now requires email field instead of username.

Migration:
- Update client code to send email instead of username
- Existing usernames mapped to emails in database
```

### Work with Multiple Todos

**One commit per major todo:**

```
# Todo 1 completed
feat(auth): add login endpoint

# Todo 2 completed (next commit)
feat(auth): add token validation middleware

# Todo 3 completed (next commit)
test(auth): add authentication tests
```

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

## When This Skill Activates

Use this Skill when:

- User uses `/jj:commit` without message argument
- User asks "how should I describe this commit"
- Generating commit message from changes
- Plan commit needs converting to reality
- User asks for commit message help
- Reviewing changes and suggesting description
