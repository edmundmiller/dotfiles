# Jujutsu Workflow Plugin

Autonomous commit stacking and curation for Jujutsu (jj). Provides Claude Code with slash commands, Skills, and hooks for stack-based commit workflows.

**Features:** Slash commands (`/jj:commit`, `/jj:split`, `/jj:squash`, `/jj:cleanup`), Agent Skills (workflow understanding, commit curation, message generation), Git translation hook, Plan-driven workflow, Auto-formatting (`jj fix`), Automatic file tracking

## Commands

### `/jj:commit [message]`

Stack commit with intelligent message generation. Auto-generates from changes or uses explicit message. Tracks new files automatically. Supports conventional commit format.

### `/jj:split <pattern>`

Split commit by pattern. Common: `test`, `docs`, `config`, or custom globs like `"*.md"`. Moves matched files to parent commit.

### `/jj:squash [revision]`

Merge commits in stack. Use for WIP commits or combining related changes before sharing.

### `/jj:cleanup`

Remove empty jj workspaces.

## Quick Start

```bash
/jj:commit "feat: add login UI"      # Stack commits (files tracked automatically)
/jj:split test                       # Separate tests from implementation
/jj:squash                           # Merge WIP commits
jj op log                            # See all operations (everything undoable)
```

## Key Principles

Stack commits, pattern-based splits, leverage snapshots (`jj op log`), everything undoable, curate before sharing

## Agent Skills

Seven auto-activating Skills provide comprehensive jj workflow understanding:

**1. Working with Jujutsu** - Core concepts, state management, plan-driven workflow, command suggestions
**2. Curating Commits** - Pattern recognition for splits/squashes, file type matching, avoiding over-curation
**3. Generating Messages** - Conventional commit format, project style matching, auto-generation from patterns
**4. Resolving Conflicts** - Identify and resolve conflicts, safe `jj restore` usage with path specifications, handling deletion conflicts
**5. Operation History** - Time travel with `jj op restore`, exploring operation log, understanding jj's event sourcing
**6. Undo Operations** - Recovering from mistakes, multiple undo scenarios, redo workflows
**7. Stacked PRs** - Working with jj-spr for submitting and updating GitHub Pull Requests

Skills activate automatically based on context. Slash commands require explicit user invocation.

## Integration

**Automatic Snapshotting:** Every operation in `jj op log`, use `jj op restore` for time travel

**Hooks:**

- **Plan-Driven:** Creates "plan:" commit for substantial tasks, validates at session end
- **Git Translation:** Intercepts git commands, suggests jj equivalents
- **Auto-formatting:** Runs `jj fix -s @` after edits
- **Session Validation:** Detects plan commits with work, suggests description updates

**Git translation:** `git status` → `jj st`, `git commit` → `jj commit`, `git log` → `jj log`, `git checkout` → `jj new`, etc.

**hunk.nvim:** Works as diff editor for interactive splitting

## Utility Scripts

The plugin includes reusable bash utility scripts that provide a clean API for common jj operations:

### `hooks/jj-state.sh`

State inspection functions for checking commit status:

```bash
# Source the script
source "$SCRIPT_DIR/../hooks/jj-state.sh"

# Check if commit has description
has_desc=$(get_commit_state)  # Returns: "has" or "none"

# Check if commit is empty
is_empty=$(is_empty_commit)  # Returns: "empty" or "has_changes"

# Get working copy status
status=$(get_working_copy_status)  # Returns: jj status output
```

### `hooks/jj-templates.sh`

Template formatting functions for consistent commit display:

```bash
# Source the script
source "$SCRIPT_DIR/../hooks/jj-templates.sh"

# Format single commit (current by default)
commit=$(format_commit_short)      # Returns: "abc123: commit message"
parent=$(format_commit_short '@-')  # Format specific revision

# Format multiple commits as list
list=$(format_commit_list '@|@-')  # Returns multi-line list

# Format ancestor chain
ancestors=$(format_ancestors 3)    # Returns: last 3 ancestors
```

**Benefits:**

- DRY principle: Eliminates ~15 lines of duplication across commands
- Single source of truth for state detection and formatting
- Testable: Comprehensive pytest coverage (19 tests)
- Reusable: Easy to integrate into new commands

**Testing:**

```bash
# Run utility script tests
uvx pytest test_hook_scripts.py -v
```

## Installation

Part of dotfiles configuration. To use in other projects: Copy plugin directory to `.claude/plugins/jj/`

## Requirements

Jujutsu (jj) installed, Claude Code v1.0.88+, basic jj familiarity

## Testing

The plugin includes comprehensive test coverage for all hooks.

```bash
# Run tests once
bun test

# Run tests in watch mode
bun test:watch

# Run specific test file
bun test hooks/jj-hooks.test.mjs
```

**Test Coverage:**

- Git-to-jj translator: Command interception, read-only vs. write detection, mapping accuracy
- Plan commit: Task vs. question detection, pattern matching, edge cases
- Integration helper: Session validation, error handling
- Workflow scenarios: Real-world command sequences
- Utility scripts: State inspection, template formatting, script structure validation (19 tests)

## Troubleshooting

**Commands not showing:** Verify `.claude-plugin/plugin.json` exists, check `which jj`
**Not a jj repo:** Run `jj git init --colocate` or `jj init`
**Git blocked:** Expected behavior - hook redirects git → jj
**Hook issues:** Verify executable (`chmod +x`), check `which uv`

## License

MIT
