# Git Helpers Plugin

Advanced Git workflow helpers for worktrees, rebasing, bisecting, and commits. This plugin provides Claude Code with specialized commands for common Git operations using the MCP git server.

## Commands

### `/git:commit`

Create a git commit using MCP git server.

**What it does:**

- Analyzes staged and unstaged changes
- Determines appropriate conventional commit type
- Creates well-formatted commit message
- Uses MCP git server for reliable git operations

**Conventional Commit Types:**

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Formatting changes
- `refactor:` - Code refactoring
- `test:` - Test additions/changes
- `chore:` - Maintenance tasks

**Features:**

- Auto-stages relevant files
- Follows Conventional Commits specification
- Reviews recent commits for style consistency
- Shows current branch and status

### `/git:worktree`

Create and manage git worktrees for parallel development.

**Use cases:**

- Work on multiple features simultaneously
- Review PRs without stashing current work
- Test different branches in parallel
- Maintain clean separation of concerns

**What it helps with:**

- Creating new worktrees
- Listing existing worktrees
- Removing worktrees when done
- Managing worktree-specific configurations

**Best practices:**

- One worktree per feature/bug/PR
- Keep worktrees in organized directory structure
- Clean up when done to avoid clutter

### `/git:rebase`

Help with git rebase operations.

**Operations supported:**

- Interactive rebasing
- Conflict resolution
- History editing
- Squashing commits
- Reordering commits

**Safety features:**

- Shows commit history before rebasing
- Explains conflict resolution strategies
- Provides rollback instructions
- Warns about force-push implications

**When to use:**

- Clean up commit history before merging
- Squash WIP commits
- Reorder commits logically
- Update feature branch with main

### `/git:bisect`

Binary search for bug introduction.

**How it works:**

1. Mark known good and bad commits
2. Git checks out commits in binary search order
3. You test each commit
4. Finds exact commit that introduced bug

**What the command helps with:**

- Starting bisect session
- Marking commits as good/bad
- Automating tests during bisect
- Interpreting bisect results
- Recovering from bisect errors

**Use cases:**

- "This worked last week, now it's broken"
- Regression testing
- Finding performance degradations
- Tracking down integration issues

## Workflow Examples

### Creating a Commit

```bash
# Make your changes
/git:commit
# Claude analyzes changes and creates properly formatted commit
```

### Parallel Development with Worktrees

```bash
/git:worktree
# "I need to work on feature-x while keeping my current work on feature-y"
# Claude helps set up a new worktree
```

### Cleaning Up History

```bash
/git:rebase
# "I have 10 WIP commits I want to squash into one"
# Claude guides you through interactive rebase
```

### Finding a Bug

```bash
/git:bisect
# "This feature broke sometime in the last 50 commits"
# Claude helps you set up and run git bisect
```

## Integration

### MCP Git Server

All commands use the MCP git server for reliable operations:

- `mcp__git__git_status`
- `mcp__git__git_diff_unstaged`
- `mcp__git__git_diff_staged`
- `mcp__git__git_add`
- `mcp__git__git_commit`
- `mcp__git__git_log`
- `mcp__git__git_branch`

### Dynamic Context

Commands automatically gather relevant context:

- Current git status
- Staged/unstaged changes
- Branch information
- Recent commit history
- Conflict status

## Installation

This plugin is part of the dotfiles configuration. It's automatically available when using Claude Code from the repository.

To enable in other projects:

1. Copy plugin directory to `.claude/plugins/git-helpers-plugin/`
2. Ensure MCP git server is configured
3. Commands will be available as `/git:*`

## Requirements

- Git installed and repository initialized
- Claude Code v1.0.88 or later
- MCP git server configured in Claude settings
- Basic familiarity with Git concepts

## Configuration

The plugin uses MCP git server which should be configured in your Claude settings. The commands have appropriate tool permissions:

```json
{
  "allowed-tools": [
    "mcp__git__git_status",
    "mcp__git__git_diff_unstaged",
    "mcp__git__git_diff_staged",
    "mcp__git__git_add",
    "mcp__git__git_commit",
    "mcp__git__git_log",
    "mcp__git__git_branch"
  ]
}
```

## Troubleshooting

**Commands not showing up:**

- Verify plugin structure: `.claude-plugin/plugin.json` exists
- Check Claude Code plugin loading: `claude --debug`
- Ensure Git is in PATH: `which git`

**MCP git server errors:**

- Verify MCP server is configured: Check Claude settings
- Test git operations manually: `git status`
- Check repository is initialized: `git rev-parse --git-dir`

**Commit command not working:**

- Ensure you have changes to commit: `git status`
- Check if files are staged: `git diff --staged`
- Verify conventional commit format is desired

**Worktree issues:**

- List existing worktrees: `git worktree list`
- Remove stale worktrees: `git worktree prune`
- Check disk space for new worktrees

## Best Practices

1. **Use specific commands** - Choose the most specific command for your task
2. **Let commands gather context** - Commands auto-collect relevant information
3. **Review before committing** - Always check the proposed commit message
4. **Clean up worktrees** - Remove when done to avoid clutter
5. **Test bisect on copy** - Practice bisect on a branch first

## Manual Git Commands

For operations beyond the plugin scope:

```bash
git status              # Check repository status
git log --graph        # Visualize commit history
git reflog             # Recovery and history
git stash              # Temporary storage
git cherry-pick        # Apply specific commits
```

## License

MIT
