# Jujutsu Workflow Plugin

Autonomous commit stacking and curation workflow for Jujutsu (jj) version control. This plugin provides Claude Code with specialized commands, Skills, and hooks for managing commits in a jj repository using a stack-based workflow.

**Features:**

- **Slash Commands** - `/jj:commit`, `/jj:split`, `/jj:squash`, `/jj:cleanup` for explicit user actions
- **Agent Skills** - Autonomous JJ workflow understanding, commit curation, and message generation
- **Git translation** - Automatic hook to suggest jj equivalents and block git commands
- **Plan-driven workflow** - Automatic commit planning and validation hooks
- **Auto-formatting** - Runs `jj fix` after edits to format code automatically

## Commands

### `/jj:commit [message]`

Stack a commit with intelligent message generation.

**Usage:**

- `/jj:commit` - Auto-generate commit message based on changes
- `/jj:commit "feat: add login UI"` - Create commit with explicit message

**Workflow:**

- If current commit has description → creates new commit on top
- If current commit needs description → describes current commit, then automatically creates new empty commit on top (unless described commit is empty)
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

## Plan-Driven Workflow

The plugin supports a plan-driven workflow where Claude commits intent BEFORE work begins:

**1. Task starts (automatic):**

```bash
# User: "Add authentication to the API"
# → Plugin creates: "plan: Add authentication to the API"
```

**2. Work happens:**

- Claude implements the feature
- Files are modified
- TodoWrite may track progress

**3. Session ends (automatic validation):**

```bash
# Plugin detects "plan:" commit with actual work
# → Suggests: Update description to reflect what was actually done
# → Use /jj:commit to describe reality
```

**With TodoWrite integration:**

```bash
# User: "Implement user management system"
# → "plan: Implement user management system"

# Claude creates todos, completes first one
# → jj new (move to next commit for next todo)

# Complete second todo
# → jj new (move to next commit)

# End result: One commit per major step
```

## Key Principles

- **Stack commits** - Each `/jj:commit` creates new commit on top
- **Pattern-based split** - Use descriptions, not file lists
- **Leverage snapshots** - Use `jj op log` and `jj op restore` for time travel
- **Everything undoable** - Operation log makes everything reversible
- **Clean history** - Curate before pushing, work however you want locally

## Agent Skills

This plugin includes three Agent Skills that Claude autonomously uses to understand and work with jj workflows. Skills are **model-invoked** - Claude automatically activates them based on context, unlike slash commands which require explicit user invocation.

### Working with Jujutsu Version Control

**When activated:** When user mentions commits, changes, version control, or working with jj repositories.

**What it provides:**
- Core jj concepts and mental model (change-based, automatic snapshotting, stack-based workflow)
- Working copy state management (`@`, `@-`, ancestors)
- Plan-driven workflow guidance
- When to suggest jj commands vs slash commands
- Git-to-JJ translation knowledge
- Best practices for jj workflows

**Example:** User says "I need to commit these changes" → Claude understands jj workflow, suggests `/jj:commit`, explains plan-driven approach if applicable.

### Curating Jujutsu Commits

**When activated:** When working with multiple commits, WIP changes, or preparing work for sharing.

**What it provides:**
- Pattern recognition for split opportunities (tests+code, docs+code, config+code)
- WIP and fixup commit detection
- When to suggest `/jj:split` vs `/jj:squash`
- File type pattern matching (test, docs, config)
- Curation workflow guidance
- Avoiding over-curation

**Example:** User makes changes mixing test files and implementation → Claude suggests: "Your changes mix tests and implementation. Consider: `/jj:split test`"

### Generating JJ Commit Messages

**When activated:** When creating commits, describing changes, or when user asks for commit message help.

**What it provides:**
- Conventional commit format (type, scope, description)
- Project-specific commit style matching
- Plan-to-reality pattern for plan-driven workflow
- Message writing guidelines (imperative mood, specificity, what/why)
- Auto-generation from file patterns
- Length and formatting best practices

**Example:** User runs `/jj:commit` without message → Claude analyzes changes, generates: "feat(auth): implement JWT-based authentication"

### Skills vs Slash Commands

**Skills (model-invoked):**
- Claude automatically uses when relevant
- Provide knowledge and understanding
- Guide workflow decisions
- Suggest appropriate commands

**Slash Commands (user-invoked):**
- User explicitly types `/jj:commit`, `/jj:split`, etc.
- Execute specific actions
- Provide consistent interface
- Work whether Skills active or not

**Example workflow:**
1. User: "I added login and some tests"
2. **Skill activates:** Claude understands mixed changes
3. **Skill suggests:** `/jj:split test` to separate concerns
4. User: `/jj:split test`
5. **Command executes:** Splits tests into separate commit
6. **Skill activates:** Claude generates commit messages for both commits

## Integration

### Automatic Snapshotting

Jj automatically snapshots your working copy when running commands. This means:

- **No manual commits needed** - Changes are tracked automatically
- **Full history preserved** - Every operation is in `jj op log`
- **Easy restoration** - `jj op restore` to go back to any state
- **Cleaner commit history** - No WIP commits cluttering your log

### Hooks

This plugin provides several Claude Code hooks for seamless jj integration:

**Plan-Driven Workflow (UserPromptSubmit):**

- Creates "plan:" commit when receiving substantial tasks
- Describes INTENT before work begins
- Enables plan validation at session end
- Silent for simple questions and clarifications

**Git-to-JJ Translation (PreToolUse):**

- Automatically intercepts git commands
- Suggests jj equivalent with explanation
- Prevents accidental git usage in jj repositories
- Works for both MCP git tools and Bash git commands

**Auto-formatting (PostToolUse):**

- Runs `jj fix -s @` after Edit/MultiEdit operations
- Automatically formats code using configured formatters (prettier, black, etc.)
- Applies fixes to current commit without creating conflicts
- Silent operation (errors suppressed)

**Session End Validation (Stop):**

- Validates plan vs actual work
- Detects "plan:" commits that now contain real work
- Suggests updating description to reflect reality
- Reminds to commit substantial uncommitted work
- Helps maintain clean, accurate commit history

The git translation hook maps common git commands:

- `git status` → `jj st`
- `git diff` → `jj diff`
- `git commit` → `jj commit`
- `git log` → `jj log`
- `git checkout` → `jj new`
- `git branch` → `jj bookmark list`
- And more (see [official git command table](https://jj-vcs.github.io/jj/latest/git-command-table/))

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

**Git commands being blocked:**

- This is expected! The hook redirects git → jj
- To temporarily disable: Comment out `PreToolUse` section in `config/claude/settings.json`
- To allow specific git commands: Add them to read-only list (git show, git blame, etc.)

**Hook not working:**

- Check hook is executable: `chmod +x config/claude/plugins/jj-workflow-plugin/hooks/git-to-jj-translator.py`
- Verify Python/uv is available: `which uv`
- Test hook manually: `echo '{"tool":{"name":"Bash","params":{"command":"git status"}}}' | ./hooks/git-to-jj-translator.py`

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
