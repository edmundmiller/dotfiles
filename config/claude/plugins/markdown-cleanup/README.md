# Markdown Cleanup Plugin

Automatically cleans up stray markdown files created during Claude Code sessions.

## Overview

This plugin runs a cleanup hook at session end to prevent accumulation of stray markdown files in your repository. It uses **session-based tracking** to identify files created during the current session and removes them unless they're documentation.

## Features

- **Session-based tracking**: Tracks when the session starts and identifies newly created files
- **Automatic cleanup**: Runs at session end via Stop hook
- **Smart preservation**: Protects documentation files (README, CHANGELOG, files in docs/ directories)
- **Repository scanning**: Checks repo root and /tmp directories
- **Silent operation**: Only notifies when files are actually removed
- **Fail-safe**: Errors don't interrupt Claude's operation

## How It Works

The plugin uses two hooks:

### UserPromptSubmit Hook (Session Start)

1. Records the current timestamp when the session begins
2. Stores timestamp in `/tmp/.claude_session_start`
3. Only runs once per session (doesn't overwrite existing timestamp)

### Stop Hook (Session End)

1. Reads the session start timestamp
2. Scans the repository root for markdown files created after session start
3. Scans temporary directories (`/tmp`, `/private/tmp`) for new files
4. Preserves important documentation files
5. Removes stray files created during the session
6. Reports cleanup statistics if files were removed

## Protected Files

The following files are **never** deleted:

- `README.md`
- `CLAUDE.md`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `LICENSE.md`
- `TODO.md`
- `NOTES.md`
- `INDEX.md`
- Any files in `docs/`, `.github/`, or other documentation directories

## Detection Logic

### Time-Based Detection

Files are identified by creation/modification time:

- Files created or modified **during the current session** are candidates for removal
- Session start time is tracked via UserPromptSubmit hook
- If no session timestamp exists, considers files from the last hour

### Protected Files

Files are **never** deleted if they:

- Have important names: `README`, `CHANGELOG`, `LICENSE`, `CONTRIBUTING` (case-insensitive patterns)
- Are in the exact safelist: `CLAUDE.md`, `TODO.md`, `NOTES.md`, `INDEX.md`
- Are in documentation directories: `docs/`, `documentation/`, `.github/`, `wiki/`

### Removal Logic

Files are removed if:

1. Created/modified during current session AND
2. Not in protected file list AND
3. Not in documentation directory

## Configuration

The plugin runs automatically with two hooks:

### Plugin Configuration (`plugin.json`)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/track-session-start.py"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/cleanup-stray-markdown.py"
          }
        ]
      }
    ]
  }
}
```

### Session Tracking

- Session start time stored in `/tmp/.claude_session_start`
- Automatically created on first user prompt
- Persists across the session
- Used by cleanup hook to identify new files

## Customization

To modify the cleanup behavior, edit `hooks/cleanup-stray-markdown.py`:

- **Add protected files**: Update `SAFELIST_EXACT` set
- **Add protected directories**: Update `SAFELIST_DIRS` set
- **Add important patterns**: Update `important_patterns` list in `is_important_file()`
- **Change session timeout**: Modify fallback time in `get_session_start_time()` (default: 1 hour)
- **Extend search locations**: Modify `find_stray_markdown_files()` function

## Safety Features

1. **Safelist protection**: Important files are never deleted
2. **Directory safelist**: Protected directories are completely skipped
3. **Limited scope**: Only scans `/tmp` directories by default
4. **Error handling**: Failures don't interrupt Claude's operation
5. **Fail-open design**: Errors allow execution to continue

## Example Output

When files are cleaned up, you'll see a system message:

```
🧹 Cleaned up 3 stray markdown file(s)
```

If there are no stray files, the hook runs silently.

## Troubleshooting

### Files not being cleaned up

- Check if files match temporary patterns
- Verify files are in `/tmp` or `/private/tmp`
- Ensure files aren't in protected directories

### Important files being deleted

- Add filenames to `SAFELIST_EXACT` in the hook script
- Add directory names to `SAFELIST_DIRS`
- Check file paths with `jj diff` before committing changes

### Hook errors

The hook is designed to fail open - errors won't block Claude's operation. Check the error message in the system response for details.

## Development

### Testing the Hook

Test the hook manually:

```bash
echo '{}' | ./hooks/cleanup-stray-markdown.py
```

### Debugging

Add debug output to the hook script or check Claude's debug logs.

## Version History

- **0.1.0** (2025-10-09): Initial release
  - PostResponse hook for automatic cleanup
  - Safe file detection and removal
  - Protection for important documentation files

## License

MIT
