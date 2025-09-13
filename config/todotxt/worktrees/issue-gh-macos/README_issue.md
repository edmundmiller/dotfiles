# Issue Action for todo.txt

Enhanced version of the [todotxt-more issue action](https://git.sr.ht/~proycon/todotxt-more/tree/master/item/todo.actions.d/issue) with macOS support and GitHub CLI integration.

## Features

- **Cross-platform notifications**: macOS osascript notifications + Linux notify-send
- **GitHub CLI integration**: Uses `gh` when available, falls back to curl/open
- **Multiple URL formats**: Supports both `issue:https://...` and `gh:owner/repo#123`
- **Issue management**: Open, close, and sync GitHub issues from todo.txt

## Setup

### Environment Variables
Add to `~/.todo/config`:
```bash
export TODO_DIR="$HOME/.todo"
export TODO_FILE="$TODO_DIR/todo.txt"
export DONE_FILE="$TODO_DIR/done.txt"
export TODO_ACTIONS_DIR="$HOME/.todo.actions.d"
export TODO_ISSUE_OPENER=open
export TODOTXT_NOTIFY=1
export GITHUB_TOKEN="$(gh auth token 2>/dev/null || echo)"
```

### GitHub CLI Authentication
```bash
gh auth login -h github.com -s repo,read:org
```

## Usage

### View/Open Issues
```bash
todo.sh -x issue <ITEM#>
```

### Close Issues (marks todo as done + closes GitHub issue)
```bash
todo.sh -x issue close <ITEM#>
```

### Sync Issues (requires pytodotxt Python package)
```bash
todo.sh -x issue sync
```

## Todo Formats

### GitHub shorthand token (recommended)
```
Fix bug in parser gh:owner/repo#123
```

### Full issue URL
```
Review PR issue:https://github.com/owner/repo/issues/456
```

## macOS Compatibility

- **Notifications**: Uses `osascript` instead of `notify-send`
- **URL opening**: Uses `open` instead of `xdg-open`
- **Grep patterns**: Uses `-E` instead of `-P` for Extended Regular Expressions

## Dependencies

- **Required**: `gh` (GitHub CLI) or `curl` + `GITHUB_TOKEN`
- **Optional**: `python3` + `pytodotxt` package (for sync functionality)

## Testing

Created private test repo `edmundmiller/todo-issue-test` for safe testing of:
- Issue opening in browser
- Issue closing via GitHub API
- macOS notification display
- Fallback behavior when gh is unavailable
