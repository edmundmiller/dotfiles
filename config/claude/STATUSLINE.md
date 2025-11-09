# Claude Code Statusline

Information-dense statusline for Claude Code that displays comprehensive jujutsu (jj) repository information at a glance.

## Features

- **Abbreviated Path**: Smart path truncation (~/f/b/project)
- **Bookmark Position**: Shows closest bookmark and commits ahead (@+N)
- **Change ID**: Displays the short change ID (colored for visibility)
- **Description**: Current change description (intelligently truncated)
- **Empty Indicator**: Shows ∅ symbol for empty changes
- **File Statistics**: Live count of added (+), modified (~), and deleted (-) files
- **Conflict Detection**: Shows ✗ when conflicts are present
- **Color Coding**:
  - Blue for bookmarks
  - Yellow for ahead count and modifications
  - Magenta for change IDs
  - Cyan for descriptions
  - Green for additions
  - Red for deletions
  - Dim gray for context and empty indicator

## Display Format

```
~/path bookmark@+N change_id "description" ∅ [+A~M-D] ✗
       │       │   │         │             │  └─ file stats (colored)
       │       │   │         │             └─ empty change symbol
       │       │   │         └─ description (truncated at 35 chars)
       │       │   └─ change ID (short, colored)
       │       └─ commits ahead of bookmark
       └─ bookmark name (or closest ancestor)
```

Example outputs:
```
~/dotfiles main z5kn8w2v "Add statusline" [+2~5-1]
~/dotfiles main@+3 abc123d "Fix authentication bug" ∅
~/d/s/project feature@+1 def456g (no description) [+1]
~/dotfiles main z5kn8 "Refactor utils" ✗
```

## Customization

Edit `bin/claude-statusline` to customize:

- **MAX_DESC_LEN**: Maximum description length (default: 35 chars)
- **Path abbreviation**: Modify the regex to change how paths are shortened
- **Colors**: Adjust color variables at the top of the script
- **Format order**: Rearrange the statusline components
- **Symbols**: Change ∅ (empty), ✗ (conflict), @+N (ahead) symbols
- **File stat display**: Modify how +/~/- counts are shown

### Available jj template fields

The script uses `jj log` templates. You can add more information:

- `change_id` / `change_id.short()` - The change ID
- `description` / `description.first_line()` - The commit description
- `bookmarks` - Any bookmarks on this change
- `author` / `author.email()` - Author information
- `committer` - Committer information
- `working_copies` - Working copy information
- `conflict` - Whether the change has conflicts
- `empty` - Whether the change is empty

See `jj help templating` for more options.

### Examples of customizations

**Show author:**
```bash
AUTHOR=$(jj log -r @ --no-graph -T 'author.email()' 2>/dev/null || echo "")
STATUSLINE="${STATUSLINE} ${DIM}(${AUTHOR})${RESET}"
```

**Add timestamp:**
```bash
TIME=$(jj log -r @ --no-graph -T 'committer.timestamp().ago()' 2>/dev/null || echo "")
STATUSLINE="${STATUSLINE} ${DIM}${TIME}${RESET}"
```

**Longer descriptions:**
```bash
MAX_DESC_LEN=60  # Instead of 35
```

## Troubleshooting

If the statusline doesn't appear:

1. Verify jj is installed: `which jj`
2. Check you're in a jj repository: `jj status`
3. Test the script directly: `$HOME/dotfiles/bin/claude-statusline`
4. Check Claude Code settings point to the right path
5. Restart Claude Code to pick up settings changes

## Path Configuration

The statusline command is configured in `config/claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "$HOME/dotfiles/bin/claude-statusline",
  "padding": 0
}
```

Adjust the path if your dotfiles are in a different location.
