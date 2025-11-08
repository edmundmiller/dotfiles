---
name: Submitting Stacked PRs with jj-spr
description: Work with jj-spr for submitting and updating stacked GitHub Pull Requests. Use when the user explicitly mentions 'jj-spr', 'jj spr', 'stack pull request', 'stacked PR', or 'submit for review'. Integrates with jj commit workflow.
allowed-tools: Bash(jj log:*), Bash(jj status:*), Bash(jj diff:*), Bash(jj spr:*), Bash(gh pr:*)
---

# Submitting Stacked PRs with jj-spr

## Purpose

Submit and manage stacked GitHub PRs using jj-spr. Integrates with jj plugin's commit stacking workflow for sharing curated commits as reviewable PRs.

## Integration with jj-workflow

**Local curation:**

```bash
/jj:commit "feat: add login UI"
/jj:split test                    # Separate concerns
/jj:squash                         # Clean up WIP commits
```

**Submit to GitHub:**

```bash
jj spr submit                      # Create PRs for entire stack
```

**The flow:** Curate locally → Submit with `jj spr submit` → Amend commits → Update with `jj spr update`

## Core Commands

### Submit PRs

```bash
jj spr submit                      # Submit all commits in stack
jj spr submit -r <change-id>       # Submit from specific commit upward
jj spr submit -r <id> --no-deps    # Submit specific commit only
```

### Update PRs

```bash
jj spr update                      # Update all PRs with local changes
jj spr update -r <change-id>       # Update specific PR
jj spr update --force              # Force update (skip checks)
```

### View Status

```bash
jj spr info                        # Show PR info for commits
jj spr info -r <change-id>         # Show info for specific commit
gh pr list                         # View PRs
gh pr view <pr-number> --web       # Open PR in browser
```

## Common Workflows

### Submit Clean Commits

```bash
# 1. Build stack locally
/jj:commit "feat(auth): add login endpoint"
/jj:commit "test(auth): add login tests"
/jj:commit "docs(auth): document auth flow"

# 2. Review and curate
jj log
/jj:split test                     # Split if needed
/jj:squash                         # Squash if needed

# 3. Submit
jj spr submit
```

**Result:** Each commit becomes a PR, stacked automatically.

### Respond to Review Feedback

```bash
# 1. Edit specific commit
jj edit <change-id>

# 2. Make changes
# ... edit files ...

# 3. Update description if needed
jj describe -m "feat(auth): add login endpoint

Addressed review feedback:
- Add input validation
- Improve error messages"

# 4. Return to working copy and update PRs
jj new
jj spr update
```

**Result:** PR updated, dependent PRs rebased automatically.

### Add to Existing Stack

```bash
# Add new commits on top
/jj:commit "feat(auth): add password reset"
/jj:commit "test(auth): add reset tests"

# Submit new commits (existing PRs unchanged)
jj spr submit
```

### Fix Bug in Middle of Stack

```bash
# Edit earlier commit
jj edit <change-id>

# Fix bug
# ... make changes ...

# Return and update all affected PRs
jj new @+
jj spr update
```

### Reorder Stack

```bash
# Reorder with rebase
jj rebase -r <commit> -d <new-parent>

# Update PRs
jj spr update
```

### Split Commit After Submitting

```bash
# Edit commit with mixed changes
jj edit <change-id>

# Split
/jj:split "*settings*"

# Return and update
jj new @+
jj spr update
```

**Result:** Original PR split into two new PRs.

## When to Use jj-spr

**Use when:**

- Commits clean and ready for review
- Managing dependent features
- Large feature split into reviewable chunks
- Responding to review feedback

**Consider alternatives when:**

- Single PR (use `jj git push` + `gh pr create`)
- Commits still messy (curate first with `/jj:commit`, `/jj:split`, `/jj:squash`)
- Collaborative feature branch (different workflow needed)

## Best Practices

### Before Submitting

```bash
/jj:split test                     # Split mixed concerns
/jj:squash                         # Squash WIP commits
jj log                             # Verify stack order
nix flake check                    # Run tests
```

### Commit Guidelines

- **One logical change per commit**: "feat(auth): add JWT validation" ✅ not "add login, logout, and profile" ❌
- **Clear messages**: First line becomes PR title, body becomes description
- **Reviewable size**: Keep commits focused and small

### Stack Management

- Keep stacks shallow (<5 PRs)
- Merge from bottom up
- Note dependencies in PR descriptions

### Handling Feedback

- **Amend commits**, don't add fixup commits
- Update commit messages to reflect changes
- `jj spr update` syncs PR descriptions

## Quick Reference

### Common Patterns

**Submit entire stack:**

```bash
jj spr submit
```

**Update after amending:**

```bash
jj edit <change-id>
# ... make changes ...
jj new
jj spr update
```

**Check stack status:**

```bash
jj log -T 'concat(change_id.short(), ": ", description)'
jj spr info
```

### Troubleshooting

**Wrong base branch:**

```bash
gh pr edit <pr-number> --base <correct-base>
```

**Out of order:**

```bash
jj rebase -r <commit> -d <new-parent>
jj spr update
```

**Conflicts after update:**

```bash
jj rebase -d main
# ... resolve conflicts ...
jj spr update
```

**WIP commits submitted:**

```bash
gh pr close <pr-number>
/jj:squash                         # Clean up
jj spr submit                      # Resubmit
```

## When This Skill Activates

Use this Skill when:

- User mentions PRs, pull requests, or GitHub reviews
- User asks about sharing work for review
- Working with stacked or dependent PRs
- Need to update PRs after changes
- Discussing code review workflows
- User mentions amending commits that have PRs
