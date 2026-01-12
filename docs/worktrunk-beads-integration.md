# Worktrunk + Beads Integration Guide

## Overview

Both **worktrunk** (`wt`) and **beads** (`bd worktree`) provide git worktree management, but they serve different purposes and can coexist in the same repository.

## Quick Reference

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `wt` | Parallel AI agent workflows | Multiple Claude/OpenCode sessions, CI-tracked features, LLM commits |
| `bd worktree` | Beads issue-specific workflows | Working with beads issues, issue-driven development |

## When to Use Each Tool

### Use `wt` (Worktrunk)

**Best for:**
- Running multiple AI agents (Claude, OpenCode) in parallel
- General feature development with CI/PR tracking
- Need LLM-generated commit messages
- CI status monitoring in `wt list`
- Team workflows with project hooks

**Example workflow:**
```bash
# Start parallel AI agent work
wt switch -c -x claude feature/api-refactor
wt switch -c -x opencode feature/ui-updates

# Check status of all agents
wt list --full

# Merge when ready
wt merge
```

### Use `bd worktree` (Beads)

**Best for:**
- Working with beads issue tracker
- Issue-specific development workflows
- Need beads daemon integration
- Investigative work with issue context

**Example workflow:**
```bash
# Create worktree for beads issue
bd worktree create .worktrees/issue-123 --branch fix/issue-123

# Work with beads in worktree (requires --no-daemon)
cd .worktrees/issue-123
bd --no-daemon list
bd --no-daemon work issue-123
```

## Technical Considerations

### Beads Daemon in Worktrees

Beads requires `--no-daemon` flag when operating in worktrees due to socket conflicts:

```bash
# Always use --no-daemon in wt-managed worktrees
cd ~/code/myproject.feature-auth
bd --no-daemon list
bd --no-daemon work issue-456
```

**Why?** The beads daemon creates `.beads/bd.sock` which conflicts across multiple worktrees. The `--no-daemon` flag runs beads in direct mode.

### Worktree Path Compatibility

Both tools can coexist with different path patterns:

**Beads convention:**
```bash
bd worktree create .worktrees/feature-name --branch feature/name
# Creates: ~/code/myproject/.worktrees/feature-name
```

**Worktrunk default:**
```bash
wt switch -c feature/name
# Creates: ~/code/myproject.feature-name (sibling directory)
```

**Result:** No conflicts - different directory structures

### Shared Git Directory

Both tools operate on the same `.git/` directory:
- ✅ Safe to use both tools in same repository
- ✅ Beads issues tracked at repository level (not worktree-specific)
- ✅ Worktrunk state stored in git config (shared)
- ✅ Both tools respect git's worktree metadata

## Recommended Workflows

### Mixed Workflow: Feature Development with Issues

```bash
# 1. Create feature worktree with worktrunk (for AI agents)
wt switch -c -x claude feature/authentication

# 2. Work on beads issues within that worktree
cd ~/code/myproject.feature-authentication
bd --no-daemon work auth-123

# 3. Check both statuses
wt list --full           # See CI status, agent activity
bd --no-daemon list      # See issue tracking
```

### Parallel Agent Workflow (No Beads)

```bash
# Multiple AI agents on different features
wt switch -c -x claude agent-1
wt switch -c -x opencode agent-2
wt switch -c -x claude agent-3

# Monitor all agents
wt list
# Output shows:
#   agent-1  🤖↑  (Claude working)
#   agent-2  💬↑  (OpenCode waiting)
#   agent-3  🤖↑  (Claude working)
```

### Issue-Driven Development (Beads-First)

```bash
# Create worktree for specific beads issue
bd worktree create .worktrees/issue-789 --branch fix/issue-789

# Work exclusively with beads
cd .worktrees/issue-789
bd --no-daemon work issue-789
bd --no-daemon show issue-789

# Merge when complete (use git directly or wt)
git checkout main
git merge fix/issue-789
bd worktree remove .worktrees/issue-789
```

## Choosing the Right Tool

### Use `wt` when you want:
- ⚡️ Fast parallel workflows (`wt switch -c -x claude`)
- 📊 CI status at a glance (`wt list --full`)
- 🤖 LLM commit messages (`wt merge` with llm integration)
- 🔄 Automated project hooks (post-create, pre-merge)
- 👥 Team-wide worktree conventions

### Use `bd worktree` when you want:
- 🐛 Issue-specific context from beads
- 📋 Issue tracking integrated with worktrees
- 🔍 Investigative work with issue details
- 🧩 Beads-aware worktree management

### Use both when you want:
- Best of both worlds: `wt` for structure, `bd` for issue context
- Remember: Use `bd --no-daemon` in wt-managed worktrees

## Configuration

### Worktrunk Config

**User config:** `~/.config/worktrunk/config.toml`
```toml
# Sibling directories (different from beads pattern)
worktree-path = "../{{ repo }}.{{ branch | sanitize }}"
```

**Project config:** `.config/wt.toml`
```toml
[post-create]
setup = "echo 'Worktree created'"
```

### Beads Config

Beads automatically detects worktrees and adjusts behavior. No special configuration needed, but remember:
- Use `--no-daemon` in worktrees
- Issues are shared across all worktrees (repository-level)

## Troubleshooting

### Beads commands hang in worktree

**Problem:** Beads daemon socket conflict

**Solution:** Always use `--no-daemon` flag:
```bash
bd --no-daemon list
bd --no-daemon work issue-123
```

### Can't find worktree with `wt list`

**Problem:** Worktree created with `bd worktree` or `git worktree`

**Solution:** Worktrunk shows all worktrees regardless of creation method:
```bash
wt list --branches  # Shows branches without worktrees too
```

### Want to use worktrunk with beads path pattern

**Problem:** Prefer `.worktrees/` directory

**Solution:** Change worktrunk path template:
```toml
# In ~/.config/worktrunk/config.toml
worktree-path = ".worktrees/{{ branch | sanitize }}"
```

## Best Practices

1. **Pick a primary tool** for worktree creation:
   - Use `wt` for AI agent workflows
   - Use `bd worktree` for issue-driven work
   - Avoid mixing randomly

2. **Always use `--no-daemon`** with beads in worktrees:
   ```bash
   alias bd='bd --no-daemon'  # Consider this alias when in worktrees
   ```

3. **Document your team's convention:**
   - If team uses `wt`, document in `.config/wt.toml`
   - If team uses `bd worktree`, document in beads README

4. **Keep path patterns consistent:**
   - Don't mix `.worktrees/` and `../repo.branch` patterns
   - Choose one and stick with it

## Examples

### Example 1: Parallel Features with CI

```bash
# Create 3 worktrees for parallel development
wt switch -c feature/auth
wt switch -c feature/api
wt switch -c feature/ui

# Check CI status
wt list --full
# Output:
#   feature/auth  ✓↑   (CI passed, ahead of main)
#   feature/api   ●↑   (CI running)
#   feature/ui    ✗↑   (CI failed)
```

### Example 2: Issue Investigation with Beads

```bash
# Create worktree for investigation
bd worktree create .worktrees/investigate-crash --branch investigate/crash-123

cd .worktrees/investigate-crash
bd --no-daemon show crash-123
bd --no-daemon comment crash-123 "Found the issue in auth.rs:42"
```

### Example 3: Combined Workflow

```bash
# Start feature in wt worktree
wt switch -c -x claude feature/payment-flow

# Track related issues with beads
bd --no-daemon work payment-123
bd --no-daemon link payment-123 payment-124

# Use wt for merge workflow
wt merge  # Generates LLM commit message, runs hooks, merges
```

## See Also

- [Worktrunk Documentation](https://worktrunk.dev)
- [Beads Worktree Guide](../beads/skills/beads/resources/WORKTREES.md)
- [Git Worktree Official Docs](https://git-scm.com/docs/git-worktree)
