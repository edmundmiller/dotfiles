# Jujutsu (JJ) Commands for Claude Code

## Overview

**Autonomous commit stacking and curation** for Claude Code. Make messy commits during development, then clean them up—all autonomously.

Based on: [Parallel Claude Code with Jujutsu](https://slavakurilyak.com/posts/parallel-claude-code-with-jujutsu/)

## Command Set (4 total)

### `/jj:commit [message]` - Stack commits
Create focused commits as you work. Each commit stacks on top of the previous one.

**Auto-generation**: Without a message, detects commit type from files:
- Test files → `test:`
- Documentation → `docs:`
- Bug fixes → `fix:`
- Multiple files → `feat:`

**Usage:**
```bash
/jj:commit                         # Auto-generate message
/jj:commit "feat: add user auth"   # Custom message
```

**What it does**: `jj describe -m "msg" && jj new` - Commits current work and creates fresh working copy

### `/jj:squash [revision]` - Merge commits
Combine commits in your stack.

**Usage:**
```bash
/jj:squash           # Merge current @ into parent
/jj:squash abc123    # Merge specific revision
```

### `/jj:split <pattern>` - Split by pattern
Separate mixed commits using smart patterns.

**Common patterns:**
- `test` / `tests` - Test files
- `docs` / `doc` - Documentation
- `config` - Configuration files
- `*.md` - Markdown files
- `*.test.ts` - TypeScript tests

**Usage:**
```bash
/jj:split test        # Split tests from implementation
/jj:split docs        # Split documentation
/jj:split "*.test.*"  # Split by glob pattern
```

**How it works**: Moves matching files back to parent commit, effectively splitting them out

### `/jj:cleanup` - Remove empty workspaces
Maintenance command to remove stale workspaces.

```bash
/jj:cleanup   # Removes empty workspaces, keeps active ones
```

## Autonomous Workflow

### Phase 1: Implementation (Make the mess)
```bash
# Claude works and commits frequently
/jj:commit "wip: add authentication"
/jj:commit "add input validation"
/jj:commit "fix edge case"
/jj:commit "add tests"

# Result: Stack of 4 commits
```

### Phase 2: Curation (Clean it up)
```bash
# Claude analyzes and curates autonomously
/jj:split test               # Separate tests
/jj:squash                   # Merge fixup commits

# Result: 2 clean commits (implementation + tests)
```

### Phase 3: Session End (Stop hook shows state)
```
📦 Workspace: claude-1234

**Commit stack:**
abc: feat: authentication implementation
def: test: authentication tests

💡 **Curation tips:**
- `/jj:commit [msg]` - Stack another commit
- `/jj:squash [rev]` - Merge commits
- `/jj:split <pattern>` - Split by pattern
- `/jj:cleanup` - Remove empty workspaces
```

## Multi-Session Workflow

JJ workspaces enable **truly parallel Claude Code sessions**:

**Window 1: Feature development**
```bash
# Auto-creates workspace: claude-1234
/jj:commit "feat: add login UI"
/jj:commit "feat: add validation"
```

**Window 2: Bug fix (parallel)**
```bash
# Auto-creates workspace: claude-1235
/jj:commit "fix: handle timeout"
```

**Later: Merge to main**
```bash
# From any workspace
jj squash -m "Complete feature"  # Manual merge to parent
```

## Automatic Behavior (Hooks)

**On session start** (UserPromptSubmit):
- Auto-creates isolated workspace if not in one
- Each session gets `.jj-workspaces/claude-<timestamp>/`

**On file edits** (PostToolUse):
- Auto-updates commit description with changed files
- Format: `WIP: file1.js, file2.py, ...`

**On session end** (Stop):
- Shows commit stack
- Displays curation tips

## Key Principles

**Everything is undoable**
- Use `jj op log` to see all operations
- Use `jj undo` to reverse any operation

**No staging area**
- Changes are always in commits
- Move changes between commits with squash/split

**Stacked commits**
- Each `/jj:commit` creates a new commit on top
- Build a stack of focused commits
- Curate the stack before merging

**Pattern-based splitting**
- No interactive mode needed
- Claude can autonomously recognize patterns
- Smart defaults for common cases

## Advanced Manual Operations

For complex scenarios, use raw `jj` commands:

```bash
jj log                    # Browse commit history
jj diff                   # See current changes
jj undo                   # Undo last operation
jj rebase -d target       # Rebase stack
jj abandon                # Discard bad commits
jj workspace list         # See all workspaces
```

## Philosophy

**Autonomous Curation** - Claude should be able to:
1. Make commits while implementing (messy is OK)
2. Recognize when commits are mixed
3. Split commits by logical concerns
4. Merge WIP/fixup commits
5. End with clean, focused commit history

**Pattern Recognition** - Instead of explicit file lists:
- "These files are tests" → `/jj:split test`
- "These are docs" → `/jj:split docs`
- "These are configs" → `/jj:split config`

**Workspace Isolation** - Each Claude session works independently:
- No conflicts between parallel sessions
- Shared history, separate working copies
- Automatic workspace creation via hooks

---

*Built on JJ's workspace feature for autonomous commit curation with Claude Code.*
