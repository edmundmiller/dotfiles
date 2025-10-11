# Jujutsu Workflow Plugin

Autonomous commit stacking and curation workflow for Jujutsu (jj) version control. This plugin provides Claude Code with specialized commands for managing commits in a jj repository using a stack-based workflow.

## Commands

### `/jj:commit [message]`

Stack a commit with intelligent message generation.

**Usage:**

- `/jj:commit` - Auto-generate commit message based on changes
- `/jj:commit "feat: add login UI"` - Create commit with explicit message

**Workflow:**

- If current commit has description → creates new commit on top
- If current commit needs description → describes current commit
- Supports conventional commit format (feat:, fix:, docs:, etc.)

**Features:**

- Auto-generates messages from file patterns (test/docs/fix/feat)
- Keeps first line under 72 characters
- Matches style of recent commits
- Never opens editor (uses `-m` flag)

### `/jj:split <pattern>`

Split commit by pattern (tests, docs, config, etc).

**Usage:**

- `/jj:split test` - Split test files into separate commit
- `/jj:split docs` - Split documentation changes
- `/jj:split "*.md"` - Split by file pattern

**Common Patterns:**

- `test` - Test and spec files
- `docs` - Documentation (\*.md, README, CHANGELOG)
- `config` - Config files (_.json, _.yaml, \*.toml)
- Custom glob patterns supported

**How it works:**
Moves matched files to parent commit, effectively splitting them out from current work.

### `/jj:squash [revision]`

Merge commits in the stack.

**Usage:**

- `/jj:squash` - Merge current commit into parent
- `/jj:squash abc123` - Merge specific revision

**When to use:**

- Multiple WIP commits for same feature
- Cleaning up incremental work
- Combining related changes before sharing

### `/jj:cleanup`

Remove empty or stale workspaces.

**Usage:**

- `/jj:cleanup` - Clean up empty jj workspaces

Maintenance command for removing empty jj workspaces across your repository. Useful when you've created multiple workspaces for parallel development and want to clean up the ones that are no longer needed.

## Workflow Example

**Stack commits as you work:**

```bash
/jj:commit "feat: add login UI"      # Stack commits
/jj:commit "add validation logic"    # Keep stacking
/jj:commit "add tests"               # Auto-generated or custom messages
```

**Curate your commits:**

```bash
/jj:split test        # Separate tests from implementation
/jj:squash            # Merge WIP/fixup commits
```

**Use automatic snapshotting:**

```bash
jj op log            # See all operations and snapshots
jj op restore <id>   # Restore to any previous state
```

## Key Principles

- **Stack commits** - Each `/jj:commit` creates new commit on top
- **Pattern-based split** - Use descriptions, not file lists
- **Leverage snapshots** - Use `jj op log` and `jj op restore` for time travel
- **Everything undoable** - Operation log makes everything reversible
- **Clean history** - Curate before pushing, work however you want locally

## Integration

### Automatic Snapshotting

Jj automatically snapshots your working copy when running commands. This means:

- **No manual commits needed** - Changes are tracked automatically
- **Full history preserved** - Every operation is in `jj op log`
- **Easy restoration** - `jj op restore` to go back to any state
- **Cleaner commit history** - No WIP commits cluttering your log

### Hooks

This plugin works with Claude Code hooks:

**On session end:**

- Stop hook runs `jj show` to display current working copy snapshot

### hunk.nvim

Commands work seamlessly with hunk.nvim as the diff editor for interactive splitting and squashing.

## Installation

This plugin is part of the dotfiles configuration. It's automatically available when using Claude Code from the repository.

To enable in other projects:

1. Copy plugin directory to `.claude/plugins/jj-workflow-plugin/`
2. Commands will be available as `/jj:*`

## Requirements

- Jujutsu (jj) installed and initialized in repository
- Claude Code v1.0.88 or later
- Basic familiarity with jj concepts (changes, revisions, stacking)

## Troubleshooting

**Commands not showing up:**

- Verify plugin structure: `.claude-plugin/plugin.json` exists
- Check Claude Code plugin loading: `claude --debug`
- Ensure jj is in PATH: `which jj`

**"Not a jj repo" errors:**

- Initialize jj: `jj git init --colocate` (in Git repo)
- Or: `jj init` (new jj repo)

**Editor opens instead of using -m flag:**

- Set `JJ_EDITOR=echo` in Claude settings
- Commands always use `-m` to avoid editor prompts

## Manual JJ Commands

For advanced operations beyond the plugin:

```bash
jj log           # Browse commit history
jj diff          # See current changes
jj undo          # Undo last operation
jj rebase        # Reorganize commits
jj abandon       # Discard bad commits
```

## License

MIT
