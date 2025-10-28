---
name: Submitting Stacked PRs with jj-spr
description: Work with jj-spr for submitting and updating stacked GitHub Pull Requests. Use when the user mentions PRs, pull requests, submitting work, stacked reviews, or sharing code for review. Integrates with jj commit workflow.
---

# Submitting Stacked PRs with jj-spr

## Purpose

Help submit and manage stacked pull requests on GitHub using jj-spr. This Skill integrates with the jj-workflow-plugin's commit stacking workflow, providing guidance on when and how to share curated commits as reviewable PRs.

## What is jj-spr?

**jj-spr** is a tool for submitting and updating GitHub Pull Requests directly from Jujutsu commits. It's designed to work seamlessly with jj's change-based model and supports stacked PRs for dependent code reviews.

**Key features:**
- Submit commits as individual PRs
- Automatic stacking of dependent PRs
- Update PRs when commits are amended
- Handles rebasing and PR updates automatically
- Works as `jj spr` subcommand

**Why use jj-spr:**
- Submit code for review without leaving terminal
- Natural integration with jj's stack-based workflow
- Amend commits and update PRs seamlessly
- Review code in logical, atomic chunks

## Integration with jj-workflow

The jj-workflow-plugin provides local commit management, and jj-spr extends this to GitHub:

**Local workflow (jj-workflow-plugin):**
```bash
# Build and curate commits locally
/jj:commit "feat: add login UI"
/jj:commit "add validation logic"
/jj:split test                    # Separate concerns
/jj:squash                         # Clean up WIP commits
```

**Submit to GitHub (jj-spr):**
```bash
# Once commits are clean and ready
jj spr submit                      # Create PRs for entire stack
```

**The flow:**
1. **Local development** → Use `/jj:commit`, `/jj:split`, `/jj:squash` to build clean commits
2. **Curation** → Organize commits into reviewable units
3. **Submission** → Use `jj spr submit` to create PRs
4. **Updates** → Amend commits locally, run `jj spr update` to sync PRs

## Core Workflow

### Step 1: Build Clean Commits Locally

Use the jj-workflow-plugin commands to create well-organized commits:

```bash
# Make changes, create commits
/jj:commit "feat(auth): add login endpoint"
/jj:commit "test(auth): add login tests"
/jj:commit "docs(auth): document authentication flow"

# Curate if needed
/jj:split test                    # Split mixed concerns
/jj:squash                         # Combine WIP commits

# Review stack before submitting
jj log
```

### Step 2: Submit Stack as PRs

Once commits are ready, submit them to GitHub:

```bash
# Submit entire stack
jj spr submit

# Submit from specific commit
jj spr submit -r <change-id>
```

**What happens:**
- Each commit becomes a separate PR
- PRs are stacked (later PRs depend on earlier ones)
- Base branches set up automatically
- PR descriptions generated from commit messages

### Step 3: Respond to Review Feedback

When reviewers provide feedback, amend the relevant commit:

```bash
# View current stack
jj log

# Edit specific commit in stack
jj edit <change-id>

# Make changes based on feedback
# ... edit files ...

# Describe changes (or use current description)
jj describe -m "feat(auth): add login endpoint

Updated to address review feedback:
- Add input validation
- Improve error messages"

# Return to working copy
jj new

# Update all affected PRs
jj spr update
```

**What happens:**
- Amended commit updates its PR
- Dependent PRs rebased automatically
- Force-pushes handled by jj-spr
- PR descriptions updated if commit message changed

### Step 4: Extend the Stack

Add new commits on top and submit them:

```bash
# Add new work on top of stack
/jj:commit "feat(auth): add password reset"
/jj:commit "test(auth): add password reset tests"

# Submit new commits (existing PRs unchanged)
jj spr submit
```

**What happens:**
- New commits become new PRs
- Stacked on top of existing PRs
- Earlier PRs unaffected

### Step 5: Merge PRs

Merge PRs from bottom of stack upward:

```bash
# Merge via GitHub UI or gh CLI
gh pr merge <pr-number> --squash

# Update local repository
jj git fetch
jj rebase -d main

# Continue with remaining PRs
```

## Common Scenarios

### Scenario 1: Simple Feature Stack

**Goal:** Submit feature with tests and docs as separate PRs

```bash
# Local development
/jj:commit "feat(api): add user profile endpoint"
/jj:commit "test(api): add profile endpoint tests"
/jj:commit "docs(api): document profile endpoint"

# Review stack
jj log

# Submit all three as stacked PRs
jj spr submit
```

**Result:** Three PRs, each reviewable independently, stacked for dependency management

### Scenario 2: Responding to PR Review

**Goal:** Update middle PR in stack based on review comments

```bash
# Current stack:
# @ PR #103: docs(api): document profile endpoint
# @ PR #102: test(api): add profile endpoint tests
# @ PR #101: feat(api): add user profile endpoint  <- needs changes

# Edit the commit that needs changes
jj edit <change-id-for-PR-101>

# Make changes based on review
# ... fix validation logic ...

# Update commit description if needed
jj describe -m "feat(api): add user profile endpoint

Addressed review feedback:
- Fixed validation to handle edge cases
- Added error handling for missing fields"

# Return to tip of stack
jj new @+

# Update all affected PRs (101, 102, 103)
jj spr update
```

**Result:** PR #101 updated with changes, PRs #102 and #103 rebased automatically

### Scenario 3: Reordering Stack

**Goal:** Realize docs should come before tests, reorder commits

```bash
# Current order:
# @ docs(api): document profile endpoint
# @ test(api): add profile endpoint tests
# @ feat(api): add user profile endpoint

# Use jj rebase to reorder
jj rebase -r <test-commit-id> -d main
jj rebase -r <feat-commit-id> -d <test-commit-id>
jj rebase -r <docs-commit-id> -d <feat-commit-id>

# Update PRs with new order
jj spr update
```

**Result:** PRs reordered, dependencies updated

### Scenario 4: Split Commit After Submitting

**Goal:** Reviewer suggests splitting one PR into two

```bash
# Current: One PR with mixed changes
# @ PR #101: feat(api): add user profile and settings

# Edit the commit
jj edit <change-id-for-PR-101>

# Split into two commits
/jj:split "*settings*"

# Result: Two commits now exist
# @ feat(api): add user settings endpoint
# @ feat(api): add user profile endpoint

# Return to tip
jj new @+

# Update PRs (old PR becomes two new PRs)
jj spr update
```

**Result:** Original PR updated to first part, new PR created for second part

## When to Use jj-spr

### Use jj-spr when:

**Ready to share work:**
- Commits are clean and well-organized
- Each commit is atomic and reviewable
- Commit messages are clear and descriptive
- Tests pass and code is ready for review

**Updating existing PRs:**
- Responding to review feedback
- Fixing bugs found in review
- Rebasing on updated main branch
- Amending commit messages

**Managing stacked reviews:**
- Multiple dependent features
- Large feature split into reviewable chunks
- Sequential work that builds on itself

### Consider alternatives when:

**Simple single PR:**
- One commit, no dependencies
- Native `jj git push` + `gh pr create` may be simpler

**Not ready for review:**
- Commits still messy or WIP
- Need more local curation first
- Use `/jj:commit`, `/jj:split`, `/jj:squash` first

**Collaborative branch:**
- Multiple people working on same feature branch
- May need different workflow

## Best Practices

### Before Submitting

**Clean up commits:**
```bash
# Split mixed concerns
/jj:split test
/jj:split docs

# Squash WIP commits
/jj:squash

# Verify commit messages are clear
jj log -T 'concat(change_id.short(), ": ", description)' --no-graph
```

**Verify stack order:**
```bash
# Check commit order makes sense
jj log

# Reorder if needed
jj rebase
```

**Ensure tests pass:**
```bash
# Run tests before submitting
nix flake check  # or your test command
```

### Writing PR-Friendly Commits

**One logical change per commit:**
- ✅ "feat(auth): add JWT token validation"
- ❌ "feat(auth): add login, logout, password reset, and user profile"

**Clear commit messages become PR titles:**
- First line becomes PR title
- Body becomes PR description
- Follow conventional commit format

**Reviewable size:**
- Keep commits focused and small
- Large changes → split into multiple commits
- Each commit should be independently reviewable

### Managing the Stack

**Keep stack shallow when possible:**
- Deep stacks (>5 PRs) hard to review
- Consider breaking into separate PR groups

**Merge from bottom up:**
- Merge lowest PR in stack first
- Then next one up, etc.
- Keeps dependencies clean

**Communicate with reviewers:**
- Explain stack structure in PR descriptions
- Note dependencies between PRs
- Use PR comments to link related PRs

### Handling Feedback

**Amend, don't add fixup commits:**
```bash
# Do this (amend commit)
jj edit <change-id>
# ... make changes ...
jj spr update

# Not this (add fixup commit)
/jj:commit "fixup: address review comments"  # ❌
```

**Keep PR descriptions updated:**
- Update commit message when making significant changes
- Note what changed in response to review
- `jj spr update` syncs PR description

## Common Commands Reference

### Submitting PRs

```bash
# Submit all commits in stack
jj spr submit

# Submit from specific commit upward
jj spr submit -r <change-id>

# Submit specific commit only
jj spr submit -r <change-id> --no-deps
```

### Updating PRs

```bash
# Update all PRs with local changes
jj spr update

# Update specific PR
jj spr update -r <change-id>

# Force update (skip checks)
jj spr update --force
```

### Viewing PR Status

```bash
# Show PR info for commits
jj spr info

# Show info for specific commit
jj spr info -r <change-id>

# View PRs in browser
gh pr list
gh pr view <pr-number> --web
```

### Stack Management

```bash
# View commit stack
jj log

# View with change IDs (useful for jj spr)
jj log -T 'concat(change_id.short(), ": ", description)'

# View bookmarks (branches)
jj bookmark list

# Create bookmark for stack top
jj bookmark create <name>
```

## Workflow Examples

### Example 1: Feature → Tests → Docs Stack

**Starting from curated commits:**

```bash
$ jj log
@ qwer feat(api): document user endpoints
@ asdf test(api): add user endpoint tests
@ zxcv feat(api): add user CRUD endpoints
@ main

$ jj spr submit
Creating PR #101: feat(api): add user CRUD endpoints
Creating PR #102: test(api): add user endpoint tests (depends on #101)
Creating PR #103: feat(api): document user endpoints (depends on #102)
```

**After review feedback on #101:**

```bash
$ jj edit zxcv
$ # ... make changes ...
$ jj describe -m "feat(api): add user CRUD endpoints

Updated based on review:
- Add rate limiting
- Improve error responses"

$ jj new @+    # Return to tip
$ jj spr update
Updating PR #101: feat(api): add user CRUD endpoints
Rebasing PR #102: test(api): add user endpoint tests
Rebasing PR #103: feat(api): document user endpoints
```

### Example 2: Adding to Existing Stack

**Starting with existing PRs:**

```bash
$ jj log
@ asdf PR #102: test(api): add user endpoint tests
@ zxcv PR #101: feat(api): add user CRUD endpoints
@ main

$ # Add new work on top
$ /jj:commit "feat(api): add user search endpoint"
$ /jj:commit "test(api): add search endpoint tests"

$ jj spr submit
Keeping existing PR #101
Keeping existing PR #102
Creating PR #103: feat(api): add user search endpoint (depends on #102)
Creating PR #104: test(api): add search endpoint tests (depends on #103)
```

### Example 3: Emergency Fix in Middle of Stack

**Need to fix bug in earlier commit:**

```bash
$ jj log
@ qwer PR #103: docs(api): document endpoints
@ asdf PR #102: test(api): add tests
@ zxcv PR #101: feat(api): add endpoints  <- bug here!
@ main

$ # Edit the buggy commit
$ jj edit zxcv
$ # ... fix bug ...
$ jj new @+

$ # Verify fix didn't break tests
$ nix flake check

$ # Update all PRs
$ jj spr update
Updating PR #101: feat(api): add endpoints
Rebasing PR #102: test(api): add tests
Rebasing PR #103: docs(api): document endpoints
```

## Comparison: jj-spr vs Native jj + gh

### Using jj-spr (Recommended for stacks)

**Pros:**
- One command submits entire stack
- Automatic PR dependencies
- Seamless updates when amending
- Handles force-pushes correctly

**Workflow:**
```bash
jj spr submit       # Submit stack
# ... make changes ...
jj spr update       # Update all PRs
```

### Using Native jj + gh CLI

**Pros:**
- No additional tool needed
- More control over PR creation
- Works with any jj workflow

**Workflow:**
```bash
# For each commit
jj bookmark create feature-1
jj git push
gh pr create --base main

# For dependent PR
jj bookmark create feature-2
jj git push
gh pr create --base feature-1

# Updating
jj git push --force
```

**Use native workflow when:**
- Single PR (not a stack)
- Want manual control over PR creation
- jj-spr not available

## Troubleshooting

### PR Created with Wrong Base

**Problem:** PR created with wrong base branch

**Solution:**
```bash
# Update PR base via GitHub UI or gh CLI
gh pr edit <pr-number> --base <correct-base>

# Or close and recreate with jj-spr
jj spr update
```

### Commits Out of Order in Stack

**Problem:** PRs dependencies don't match desired order

**Solution:**
```bash
# Reorder commits with jj rebase
jj log    # Identify commit IDs
jj rebase -r <commit> -d <new-parent>

# Update PRs with new order
jj spr update
```

### PR Conflicts After Update

**Problem:** Force push creates conflicts

**Solution:**
```bash
# Rebase on latest main
jj rebase -d main

# Resolve conflicts if any
jj status
# ... resolve conflicts ...

# Update PRs
jj spr update
```

### Accidentally Submitted WIP Commits

**Problem:** Submitted commits that aren't ready

**Solution:**
```bash
# Close PRs via GitHub
gh pr close <pr-number>

# Or clean up locally and resubmit
/jj:squash        # Clean up commits
jj spr submit     # Resubmit clean version
```

## When This Skill Activates

Use this Skill when:
- User mentions submitting PRs or pull requests
- User asks about sharing work for review
- Working with stacked or dependent PRs
- User mentions GitHub reviews
- Need to update existing PRs after changes
- User asks "how do I create a PR" in jj context
- Discussing code review workflows
- User mentions amending commits that have PRs
