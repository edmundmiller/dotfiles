---
name: Curating Jujutsu Commits
description: Help curate and organize commits in jujutsu repositories. Use when working with multiple commits, WIP changes, or preparing work for sharing. Suggests when to split, squash, or reorganize commits based on change patterns.
allowed-tools: Bash(jj log:*), Bash(jj status:*), Bash(jj diff:*)
---

# Curating Jujutsu Commits

## When to Curate

**Suggest curation:**

- Before sharing work (PR, pushing)
- Commits mix unrelated concerns (tests+code, docs+code, config+code)
- WIP, fixup, or temporary commits present

**Don't suggest when:**

- Changes simple and focused
- Single commit, one concern
- Early exploration phase

## Split Patterns

Use `/jj:split <pattern>` when mixing concerns:

**Tests + implementation:**

```
Your changes include both implementation and tests. Consider:
/jj:split test
```

**Docs + code:**

```
Your changes mix code and documentation. Consider:
/jj:split docs
```

**Config + features:**

```
Your changes include configuration. Consider:
/jj:split config
```

**Common patterns:** `test`, `docs`, `config`, `*.{ext}`, custom globs

## Squash Patterns

Use `/jj:squash` when combining commits:

**Multiple WIP commits:**

```
You have multiple WIP commits for same feature. Consider:
/jj:squash
```

Indicators: "WIP", "wip", "fixup", "temp", "checkpoint" messages

**Fixup commits:**

```
This looks like a fixup for your previous commit. Consider:
/jj:squash
```

Indicators: "fix typo", "fix tests", "fix formatting" messages

**Related small changes:**

```
These commits are closely related. Consider:
/jj:squash
```

Indicators: Same feature/scope, same work session

## Curation Workflow

1. Review stack: `jj log`
2. Split mixed concerns: `/jj:split <pattern>`
3. Squash WIP commits: `/jj:squash`
4. Verify: `jj log`, `jj diff -r <commit>`
5. Update descriptions: `/jj:commit` or `jj describe`

## Avoiding Over-Curation

**Don't suggest when:**

- Single purpose changes (all files work toward one goal)
- Tightly coupled changes (splitting breaks logical cohesion)
- Already atomic (commit focused and clear)
- Early exploration phase

**Good single commits:** "Refactor auth module", "Add user profile page" (template+route+tests), "Fix memory leak" (investigation+fix)

## TodoWrite Integration

One commit per major todo completion. Use `jj new` between todos. Don't suggest splitting if commits already align with todo structure.

## When This Skill Activates

- Multiple commits to organize
- Changes mix file types or concerns
- User mentions preparing for PR/sharing
- WIP or fixup commits present
- User asks about organizing commits
- Before suggesting pushing or creating PRs
