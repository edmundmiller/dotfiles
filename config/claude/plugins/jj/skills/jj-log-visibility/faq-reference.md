# Log and Visibility - Detailed FAQ

## Q: Where is my commit? Why isn't it visible in `jj log`?

**Answer:** By default, jj shows local commits and their parents only. Your commit may be hidden if it's been abandoned, superseded, or isn't reachable from your current working copy.

**Check visibility:**
```bash
jj log -r 'all()'  # See ALL commits, including hidden ones
```

**Common reasons for "missing" commits:**

### 1. Commit was abandoned

When you use `jj abandon` or certain operations, commits become hidden.

**Find abandoned commits:**
```bash
jj log -r 'all()' | grep -A 2 -B 2 "abandoned"
```

**Restore:**
```bash
jj new <commit-id>  # Make it visible by creating a child
```

### 2. Commit is on different branch/bookmark

The commit exists but isn't in your current lineage.

**Find it:**
```bash
# Search by description
jj log -r 'description(keyword)'

# Show all bookmarks
jj log -r 'bookmarks()'

# Show specific bookmark's commits
jj log -r 'ancestors(bookmark(feature))'
```

### 3. Commit is a remote commit you haven't worked on

Remote commits aren't shown unless you have local work based on them.

**See remote commits:**
```bash
jj log -r '..'  # All visible commits
jj log -r 'remote_bookmarks()'  # Remote bookmark commits
```

### 4. Commit was superseded by rewrite

If you amended or rebased, the old version is hidden.

**See evolution history:**
```bash
jj evolog  # Shows evolution of current commit
jj evolog -r <commit-id>  # Evolution of specific commit
```

## Q: What are elided revisions? How do I display them?

**Answer:** Elided revisions appear when intermediate commits exist between shown revisions but aren't included in the filtered results. Jj shows `◆  <several revisions>` to indicate hidden intermediate commits.

**Example output:**
```
@  zxyw abc123 my feature work
│  ◆  <several revisions>  ← These are elided
◆  pqrs def456 main
```

**Why this happens:**
- The log is filtered by a revset
- Intermediate commits don't match the filter
- But they exist in the commit graph

**Display elided commits:**

### Method 1: Use `connected()` revset

```bash
# Show all commits connecting two commits
jj log -r 'connected(abc123, def456)'
```

This displays the full chain between the two commits.

### Method 2: Show more ancestors

```bash
# Show 20 levels of ancestors from @
jj log -r 'ancestors(@, 20)'

# Show all ancestors
jj log -r 'ancestors(@)'
```

### Method 3: Use range syntax

```bash
# Show all commits between two points
jj log -r 'def456..abc123'
```

### Method 4: Show everything

```bash
# Nuclear option: show all visible commits
jj log -r '..'
```

**Understanding the display:**
- `◆` marks the point where revisions are elided
- Number of elided commits not always shown
- Use `connected()` to see the actual commits

## Q: How do I get `jj log` to show what `git log` would show?

**Answer:** Run `jj log -r '..'` to list all visible commits excluding the root, similar to `git log --all`.

**Git to Jj translations:**

### Current branch history
```bash
# Git
git log

# Jj - show ancestors of current commit
jj log -r '@-'
# or
jj log -r 'ancestors(@)'
```

### All branches
```bash
# Git
git log --all

# Jj - show all visible commits
jj log -r '..'
```

### Last N commits
```bash
# Git
git log -n 10

# Jj - limit output
jj log --limit 10
# or show last 10 ancestors
jj log -r 'ancestors(@, 10)'
```

### With file paths
```bash
# Git
git log path/to/file

# Jj - filter by file
jj log -r 'file(path/to/file)'
```

### Oneline format
```bash
# Git
git log --oneline

# Jj - configure template
jj log --template 'commit_id.short() ++ " " ++ description.first_line()'
```

### Since/until dates
```bash
# Git
git log --since="2024-01-01"

# Jj
jj log -r 'after("2024-01-01")'
```

**Key differences:**

| Git | Jujutsu | Notes |
|-----|---------|-------|
| `git log` | `jj log -r '@-'` | Current lineage |
| `git log --all` | `jj log -r '..'` | All refs/bookmarks |
| `git log --oneline` | custom template | Configure display |
| `git log -- file` | `jj log -r 'file(...)' ` | File filtering |
| `git reflog` | `jj op log` + `jj evolog` | Different concepts |

## Q: Can I monitor how `jj log` evolves?

**Answer:** Yes! Use watch tools with jj commands. The `watchexec` tool can monitor `.jj/repo/op_heads/heads` for changes. Alternatively, try `jj-fzf` or check the wiki for TUIs/GUIs.

**Option 1: Using `watch` (basic)**

```bash
# Refresh every 1 second
watch -n 1 jj log

# With color
watch -n 1 --color jj log --color=always
```

**Limitations:**
- Basic display
- May flicker
- No interaction

**Option 2: Using `hwatch` (better)**

Install: `cargo install hwatch`

```bash
# Better formatting and control
hwatch -n 1 jj log

# With diff highlighting
hwatch -n 1 -d jj log
```

**Features:**
- Shows diffs between updates
- Better terminal handling
- Configurable refresh

**Option 3: Using `viddy` (interactive)**

Install: `cargo install viddy`

```bash
# Interactive monitoring
viddy jj log

# Inside viddy:
# - s: select rows to diff
# - t: toggle time machine mode
# - ?: help
```

**Features:**
- Interactive time travel through snapshots
- Row selection and diffing
- Pause and resume

**Option 4: Using `watchexec` (efficient)**

Install: `cargo install watchexec-cli`

```bash
# Only run when .jj changes
watchexec -w .jj/repo/op_heads/heads jj log

# More specific
watchexec -w .jj/repo/op_heads/heads -w .jj/repo/working_copy jj log
```

**Features:**
- Triggers only on actual changes
- More efficient than polling
- Doesn't waste CPU

**Option 5: TUI/GUI tools**

Check the [jj wiki](https://github.com/martinvonz/jj/wiki) for:
- **jj-fzf**: Interactive commit browser with fzf
- **gg**: GUI for jujutsu
- **lazyjj**: TUI interface
- **jjui**: Terminal UI

**Option 6: Custom script**

```bash
#!/bin/bash
# monitor-jj.sh
while true; do
  clear
  date
  echo "---"
  jj log --limit 20
  sleep 2
done
```

**Pro tip for development:**

Monitor multiple views:
```bash
# In tmux/screen, split panes:
# Pane 1: jj log
hwatch -n 1 jj log

# Pane 2: jj status
hwatch -n 1 jj status

# Pane 3: working directory
hwatch -n 1 -d ls -ltr
```

## Advanced Visibility Patterns

### Show only your work

```bash
# Commits by you
jj log -r 'author(your-email@example.com)'

# Or use mine() if configured
jj log -r 'mine()'
```

Configure `mine()`:
```toml
# ~/.jjconfig.toml
[revsets]
mine = "author(your-email@example.com)"
```

### Show work in progress

```bash
# Commits without proper descriptions
jj log -r 'description(exact:"") | description(regex:"^(wip|WIP|fixup)")'

# Empty commits
jj log -r 'empty()'

# Commits with conflicts
jj log -r 'conflict()'
```

### Show recent activity

```bash
# Last 24 hours
jj log -r 'after(yesterday)'

# Last week
jj log -r 'after("1 week ago")'

# Between dates
jj log -r 'after("2024-01-01") & before("2024-02-01")'
```

### Show by file involvement

```bash
# Commits touching specific file
jj log -r 'file(src/main.rs)'

# Commits touching any Rust file
jj log -r 'file("glob:src/**/*.rs")'

# Commits touching files matching pattern
jj log -r 'file("glob:**/test_*.py")'
```

### Complex filters

```bash
# Your commits from last week that aren't empty
jj log -r 'mine() & after("1 week ago") & ~empty()'

# Commits on feature branches (with bookmarks) that have conflicts
jj log -r 'bookmarks() & conflict()'

# Abandoned or hidden commits
jj log -r 'all() & ~visible_heads()'
```

## Troubleshooting

### Commit exists but not in log

**Problem:** You know the commit exists (you have the ID) but it's not showing.

**Diagnosis:**
```bash
# Check if it exists
jj show <commit-id>

# Check its visibility
jj log -r 'all()' | grep <commit-id>

# Check if it's abandoned
jj log -r '<commit-id>' -T 'is_abandoned'
```

**Fix:**
```bash
# Make visible by creating child
jj new <commit-id>

# Or explicitly mark as visible (advanced)
jj new <commit-id> && jj abandon @  # Creates then removes child
```

### Too many commits in log

**Problem:** `jj log` shows too much history.

**Solutions:**
```bash
# Limit output
jj log --limit 20

# Show only recent ancestors
jj log -r 'ancestors(@, 10)'

# Show only your work
jj log -r 'mine()'

# Configure default revset
# Add to ~/.jjconfig.toml:
[ui]
default-revset = "ancestors(@, 20)"
```

### Log is confusing/cluttered

**Problem:** Log output is hard to read.

**Solutions:**

1. **Custom templates:**
```bash
# Simpler format
jj log --template 'commit_id.short() ++ " " ++ description.first_line() ++ "\n"'

# Configure default in ~/.jjconfig.toml:
[ui]
default-template = '''
commit_id.short() ++ " "
++ description.first_line()
++ "\n"
'''
```

2. **Use revsets to filter:**
```bash
# Only important commits
jj log -r 'bookmarks() | @'

# Exclude certain commits
jj log -r '~description(regex:"^(wip|temp)")'
```

3. **Use GUIs/TUIs:**
- Try `jj-fzf` for interactive browsing
- Check wiki for graphical tools

## Reference: Visibility Revsets

```bash
# Default view
jj log                         # Local commits + parents

# Expanded views
jj log -r 'all()'             # Everything including hidden
jj log -r '..'                # All visible commits
jj log -r 'visible_heads()'   # All visible head commits

# Ancestors/descendants
jj log -r 'ancestors(@)'      # All ancestors of @
jj log -r 'ancestors(@, 10)'  # Last 10 ancestors
jj log -r 'descendants(@)'    # All descendants of @

# Connections
jj log -r 'connected(a, b)'   # Commits connecting a and b
jj log -r 'a..b'              # Range from a to b

# Filters
jj log -r 'description(text)' # Description contains text
jj log -r 'author(name)'      # Author matches name
jj log -r 'mine()'            # Your commits
jj log -r 'empty()'           # Empty commits
jj log -r 'conflict()'        # Commits with conflicts

# Time-based
jj log -r 'after(date)'       # After date
jj log -r 'before(date)'      # Before date

# Bookmarks
jj log -r 'bookmarks()'       # Commits with bookmarks
jj log -r 'bookmark(name)'    # Specific bookmark

# File-based
jj log -r 'file(path)'        # Commits touching file
```
