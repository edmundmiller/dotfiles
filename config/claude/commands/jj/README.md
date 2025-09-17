# Jujutsu (jj) Workflows for Claude Code

This document analyzes the two main jj workflows and provides recommendations for AI-assisted development with Claude Code.

## Workflow Comparison

### The Squash Workflow ⭐ **RECOMMENDED**

**Pattern**: Describe → New → Implement → Squash

```bash
jj describe -m "what you're about to do"    # 1. Describe the work
jj new                                      # 2. Create empty change
# Make your changes                        # 3. Implement
jj squash                                   # 4. Complete work
```

**Advantages for Claude Code:**
- **Matches AI working style**: Claude works on focused tasks and completes them
- **Clear staging metaphor**: Changes accumulate in current commit until ready
- **Better error recovery**: Mistakes stay in working commit, easy to undo
- **Simpler mental model**: Linear progression that maps to task execution
- **Safe by default**: Nothing is finalized until explicit squash

### The Edit Workflow

**Pattern**: Dynamic change manipulation with `jj edit` and insertion

```bash
jj new                           # Create change
jj new -B                        # Insert change before current
jj edit <change-id>              # Edit any change
jj next --edit                   # Navigate and edit
```

**Why it's less suitable for Claude:**
- **Too dynamic**: Complex navigation between changes confuses AI reasoning
- **Overkill for most tasks**: Claude typically works on one focused task
- **More complex state tracking**: Requires sophisticated change management
- **Non-linear workflow**: Doesn't match Claude's sequential task approach

## Current Implementation

Our Claude commands implement the **Squash Workflow**:

### Available Commands

- **`@squash`** - Complete work via squash workflow
- **`@describe`** - Write clear commit messages
- **`@split`** - Split mixed changes into focused commits
- **`@undo`** - Safety net for any operation
- **`@rebase`** - Reorganize commits

### Command Features

All commands support:
- **Argument passing**: `@squash "commit message"`
- **Interactive fallback**: Show options when no arguments provided
- **Claude 4 Sonnet**: Upgraded model for better reasoning
- **Proper permissions**: Fixed colon syntax for all jj operations

## Workflow in Practice

### Typical Claude Code Session

1. **Start new work**:
   ```bash
   @describe "feat: implement user authentication"
   jj new
   ```

2. **Claude implements changes**:
   - Reads files, understands requirements
   - Makes code changes across multiple files
   - Tests and validates implementation

3. **Complete work**:
   ```bash
   @squash "feat: implement user authentication

   - Add login/logout endpoints
   - Implement JWT token handling
   - Add user session management
   - Include comprehensive tests"
   ```

### Handling Mistakes

If something goes wrong:
```bash
@undo                    # Undo last operation
jj op log               # See operation history
jj op restore <id>      # Time-travel to any point
```

### Mixed Changes

When working on multiple concerns:
```bash
@split                  # Split into focused commits
@describe "fix: bug"    # Describe each part
@describe "feat: new"   # Separately
```

## Best Practices

### For Claude Code Development

1. **Always describe first**: Use `@describe` to set clear intent
2. **One feature per workflow**: Don't mix unrelated changes
3. **Use squash for completion**: Finalize work only when fully tested
4. **Leverage safety**: `@undo` is always available
5. **Split when needed**: Keep commits focused and atomic

### Integration with Development Tools

- **Testing**: Run tests before squashing
- **Linting**: Validate code quality in working commit
- **Review**: Use `jj show` to review changes before squash
- **Documentation**: Update docs as part of the same workflow

## Why This Matters

The choice of workflow affects:
- **AI effectiveness**: How well Claude can reason about changes
- **Error recovery**: How easily mistakes can be corrected
- **Code quality**: How focused and reviewable commits become
- **Development speed**: How quickly tasks can be completed

The **Squash Workflow** optimizes all these factors for AI-assisted development.

## References

- [Squash Workflow Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/real-world-workflows/the-squash-workflow.html)
- [Edit Workflow Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/real-world-workflows/the-edit-workflow.html)
- [Jujutsu Documentation](https://jj-vcs.github.io/jj/)

---

*This analysis confirms that our current squash workflow implementation is optimal for Claude Code usage.*