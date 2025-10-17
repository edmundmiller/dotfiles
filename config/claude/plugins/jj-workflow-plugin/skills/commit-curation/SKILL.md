---
name: Curating Jujutsu Commits
description: Help curate and organize commits in jujutsu repositories. Use when working with multiple commits, WIP changes, or preparing work for sharing. Suggests when to split, squash, or reorganize commits based on change patterns.
---

# Curating Jujutsu Commits

## Purpose

Help organize commits into clean, reviewable, atomic units before sharing. This Skill provides guidance on when and how to curate commits in a jujutsu repository.

## When to Curate

**Good times to suggest curation:**
- Before sharing work (PR, pushing to remote)
- After completing a feature with multiple incremental commits
- When commits mix unrelated concerns
- When you notice WIP, fixup, or temporary commits

**Don't suggest curation when:**
- Changes are simple and focused
- Single commit addresses one concern
- Work is still in early exploration
- User explicitly wants incremental history

## Split Pattern Recognition

Suggest `/jj:split <pattern>` when commits mix concerns:

### Test Files Mixed with Implementation

**Pattern:** Changes include both source code and test files

**Indicators:**
- Files matching: `*test*.{py,js,ts}`, `*spec*.{py,js,ts}`, `test_*.py`, `*Test.java`
- Mixed with implementation in same commit

**Suggestion:**
```
Your changes include both implementation and tests. Consider splitting:
/jj:split test
```

**Why:** Tests and implementation are easier to review separately

### Documentation Mixed with Code

**Pattern:** Changes include both code and documentation

**Indicators:**
- Files matching: `*.md`, `README*`, `CHANGELOG*`, `docs/**/*`
- Mixed with code changes

**Suggestion:**
```
Your changes mix code and documentation. Consider splitting:
/jj:split docs
```

**Why:** Documentation and code changes reviewed by different people/processes

### Configuration Mixed with Features

**Pattern:** Changes include both config and feature code

**Indicators:**
- Files matching: `*.json`, `*.yaml`, `*.toml`, `*.ini`, `.env*`, `*config*`
- Mixed with feature implementation

**Suggestion:**
```
Your changes include configuration updates. Consider splitting:
/jj:split config
```

**Why:** Config changes often need separate security/ops review

### File Type Patterns

**Common split patterns:**
- `test` → Test and spec files
- `docs` → Documentation (*.md, README, CHANGELOG)
- `config` → Config files (*.json, *.yaml, *.toml)
- `*.{ext}` → Specific file types
- Custom glob patterns

## Squash Pattern Recognition

Suggest `/jj:squash` when commits should be combined:

### Multiple WIP Commits

**Pattern:** Sequential commits with WIP, fixup, or similar messages

**Indicators:**
- Messages like "WIP", "wip", "fixup", "temp", "checkpoint"
- Multiple commits for same logical change
- Sequential commits touching same files

**Suggestion:**
```
You have multiple WIP commits for the same feature. Consider squashing:
/jj:squash
```

**Why:** Clean up incremental work into cohesive commits

### Fixup Commits

**Pattern:** Later commits fix earlier commits

**Indicators:**
- Messages like "fix typo", "fix tests", "fix formatting"
- Touching same files as recent commit
- Small changes that belong with earlier work

**Suggestion:**
```
This looks like a fixup for your previous commit. Consider squashing:
/jj:squash
```

**Why:** Fixes should be part of original commit in shared history

### Related Small Changes

**Pattern:** Multiple small commits that logically belong together

**Indicators:**
- Same feature/scope in multiple commits
- Commits from same work session
- Would be clearer as single commit

**Suggestion:**
```
These commits are closely related. Consider combining:
/jj:squash
```

**Why:** Atomic commits easier to review and understand

## Curation Workflow

**Typical curation sequence:**

1. **Review current stack:**
   ```bash
   jj log
   ```

2. **Identify mixed concerns** → Use `/jj:split <pattern>`

3. **Identify WIP commits** → Use `/jj:squash`

4. **Verify result:**
   ```bash
   jj log
   jj diff -r <commit>
   ```

5. **Update descriptions if needed** → Use `/jj:commit` or `jj describe`

## Examples

### Example 1: Mixed Test and Implementation

**Before:**
```
@ abc123: Add login feature and tests
  - src/auth/login.py       (new)
  - src/auth/test_login.py  (new)
  - src/auth/config.yaml    (new)
```

**Suggest:**
```
Your commit mixes implementation, tests, and config. Consider:

1. /jj:split test        # Separate tests
2. /jj:split config      # Separate config

Result: Three focused commits
```

### Example 2: WIP Commits

**Before:**
```
@ abc123: WIP: fix validation
@ def456: WIP: add validation
@ ghi789: Add user form
```

**Suggest:**
```
You have two WIP commits for validation. Consider:

jj edit def456           # Edit the first validation commit
/jj:squash               # Squash abc123 into def456

Result: Clean commit history
```

### Example 3: Documentation Update

**Before:**
```
@ abc123: Implement OAuth and update README
  - src/oauth.py    (new)
  - README.md       (modified)
  - docs/oauth.md   (new)
```

**Suggest:**
```
Your commit mixes OAuth implementation and documentation. Consider:

/jj:split docs

Result:
- Commit 1: Implement OAuth (code only)
- Commit 2: Document OAuth (docs only)
```

## Change Pattern Analysis

**Analyzing current changes:**
```bash
jj status                    # See what's changed
jj diff                      # Review changes
jj log -r 'ancestors(@, 5)'  # View recent stack
```

**Questions to ask:**
1. Do changes serve multiple purposes?
2. Could parts be reviewed separately?
3. Do file types suggest natural splits?
4. Are there WIP or fixup commits?
5. Would this be easier to understand as multiple commits?

## Avoiding Over-Curation

**Don't suggest curation when:**

- **Single purpose changes**: All files work toward one goal
- **Tightly coupled changes**: Splitting would break logical cohesion
- **Already atomic**: Commit is focused and clear
- **Early exploration**: User is still figuring things out

**Examples of good single commits:**
- "Refactor authentication module" (all auth files together)
- "Add user profile page" (template + route + tests together)
- "Fix memory leak in data processor" (investigation + fix together)

## Integration with TodoWrite

When user has TodoWrite todos:

**Pattern:** One commit per major todo completion

**Workflow:**
1. Complete todo
2. Use `/jj:commit` to describe work
3. `jj new` for next todo
4. Repeat

**Don't suggest splitting** if commits align with todo structure (already organized)

## Best Practices

**Do:**
- Suggest curation before sharing work
- Recognize common file patterns (test, docs, config)
- Explain why splitting helps review
- Provide specific `/jj:split` or `/jj:squash` commands

**Don't:**
- Over-curate working commits
- Split tightly coupled changes
- Suggest curation during active development
- Make curation feel mandatory

## When This Skill Activates

Use this Skill when:
- User has multiple commits to organize
- Changes mix different file types or concerns
- User mentions preparing work for PR/sharing
- WIP or fixup commits are present
- User asks about organizing commits
- Before suggesting pushing or creating PRs
