# jj + Claude Code Quick Reference

## Claude Code Workflow Commands

### Starting Work

```bash
jj new main           # Start from main branch
jj new                # Continue from current position
jj describe -m "msg"  # Add description to working copy
```

### While Working with Claude Code

```bash
jj status            # Check what Claude changed
jj diff              # Review Claude's modifications
jj split             # Separate unrelated changes Claude made
```

### Saving Progress

```bash
jj commit -m "msg"   # Save work and start fresh
jj squash            # Merge into previous commit
```

### When Claude Code Makes Multiple Changes

```bash
# Scenario: Claude made 3 different fixes in one go
jj diff              # Review all changes
jj split             # Interactive split
jj log               # See the separated commits
```

### Undoing Claude Code Changes

```bash
jj op log            # See what operations happened
jj undo              # Undo last jj operation
jj op restore <id>   # Restore to specific point
```

## Common Claude Code + jj Patterns

### Pattern: "Claude, fix this bug"

```bash
jj new main                      # Start clean
# Claude makes fixes...
jj commit -m "fix: [issue]"      # Commit the fix
jj git push --change @-          # Push to GitHub
```

### Pattern: "Claude, refactor this module"

```bash
jj new                           # Start from current
# Claude refactors...
jj diff                          # Review changes
jj split                         # Split if multiple refactors
jj commit -m "refactor: [what]"  # Commit each piece
```

### Pattern: "Claude made too many changes"

```bash
jj diff                          # See everything
jj split                         # Separate changes
# Or if you want to undo:
jj op log                        # Find before Claude's work
jj op restore <id>               # Go back to that point
```

### Pattern: Working on feature, need urgent fix

```bash
# Working on feature...
jj describe -m "WIP: feature"    # Save current state
jj new main                      # Start fix from main
# Fix issue...
jj commit -m "fix: urgent"       # Commit fix
jj git push --change @-          # Push fix
jj edit <feature-commit-id>      # Back to feature
```

## Your Dotfiles-Specific Commands

### With `hey` Command Integration

```bash
# Make config changes
hey test             # Test without switching
hey rebuild          # Apply changes
jj commit -m "msg"   # Commit if it works
hey rollback         # Or rollback if issues
```

### Typical Dotfiles Workflow

```bash
jj new main                          # Start from main
# Edit config files...
hey test                             # Test changes
jj commit -m "feat(module): change"  # Commit
jj git push --change @-              # Push to GitHub
```

## Git Integration Commands

### Sync with GitHub

```bash
jj git fetch                     # Get latest from GitHub
jj git push --change @-          # Push current work
jj git push --all                # Push all bookmarks
```

### Working with Branches/Bookmarks

```bash
jj bookmark create feature-name  # Create bookmark
jj bookmark list                 # List all bookmarks
jj git push --bookmark feature-name  # Push specific bookmark
```

## Safety Commands

### Before Risky Operations

```bash
jj op log            # Note current operation ID
# Do risky thing...
jj op restore <id>   # Restore if needed
```

### Check What Changed

```bash
jj diff              # Current changes
jj diff -r @-        # Previous commit's changes
jj show <commit>     # Show specific commit
```

## Key Concepts to Remember

1. **@ is your current position** - The working-copy commit
2. **No staging needed** - All changes tracked automatically
3. **Every operation is recorded** - Check `jj op log`
4. **Commits are cheap** - Make many small ones
5. **You can edit any commit** - Use `jj edit <commit>`
6. **jj undo is your friend** - Reverses last operation

## Keyboard-Friendly Aliases

Add to your shell config:

```bash
alias js='jj status'
alias jd='jj diff'
alias jl='jj log'
alias jn='jj new'
alias jc='jj commit'
alias ju='jj undo'
```

## Emergency Recovery

```bash
# "I messed everything up!"
jj op log --limit 20   # Find a good point
jj op restore <id>     # Go back to it

# "I can't find my work!"
jj log -r 'all()'      # Show ALL commits
jj log -r 'author(emiller)'  # Your commits

# "I need to see what changed"
jj evolog              # Evolution of current commit
jj diff --from <rev> --to <rev>  # Compare any commits
```

## Pro Tips for Claude Code Users

1. **Let Claude work, then organize**: Don't interrupt Claude mid-task. Let it finish, then use `jj split` to organize.

2. **Describe WIP often**: Use `jj describe -m "WIP: ..."` to mark work in progress.

3. **Commit messages**: Follow conventional commits:
   - `fix:` for bug fixes
   - `feat:` for features
   - `refactor:` for refactoring
   - `docs:` for documentation
   - `chore:` for maintenance

4. **Use op log liberally**: Before any complex operation, check `jj op log` to note where you are.

5. **Small commits**: Since commits are cheap in jj, make many small ones rather than few large ones.

---

**Remember**: In jj, you're always safe. The operation log tracks everything, so you can always recover!
