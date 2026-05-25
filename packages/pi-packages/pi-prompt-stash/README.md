# pi-prompt-stash

Git-stash for your train of thought. Save prompt drafts, restore them later. Stashes persist across sessions.

## Install

```bash
pi install npm:pi-prompt-stash
```

## Shortcuts

| Key            | Action                                          |
| -------------- | ----------------------------------------------- |
| `ctrl+s`       | Open editor to capture and stash a prompt draft |
| `ctrl+shift+s` | Pop most recent stash to editor                 |

## Commands

```
/stash              → list all stashes (interactive picker)
/stash <text>       → save text directly as a stash
/stash pop [n]      → pop stash n (default: 1) to editor
/stash drop [n]     → drop stash n without restoring
/stash clear        → clear all stashes
```

## How it works

Stashes are stored in `~/.pi/agent/prompt-stash.json`. They persist across sessions and are reloaded on session start. The interactive picker (`/stash`) lets you restore, view, edit, or delete individual stashes.

## Status bar

Shows stash count in the status bar when stashes exist: `stash: 3 stashes`
