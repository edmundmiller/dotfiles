# pi-non-interactive

Prevent agent hangs on interactive commands. Overrides the bash tool to inject env vars that make git and other tools non-interactive.

## Install

```bash
pi install npm:pi-non-interactive
```

## What it does

Replaces the default bash tool with one that injects these env vars into every command:

| Variable              | Value  | Effect                                                               |
| --------------------- | ------ | -------------------------------------------------------------------- |
| `GIT_EDITOR`          | `true` | `git rebase --continue`, `git commit` (no -m) succeed without editor |
| `GIT_SEQUENCE_EDITOR` | `true` | `git rebase -i` sequence editing                                     |
| `GIT_PAGER`           | `cat`  | `git log`, `git diff`, `git show` don't hang on pager                |
| `PAGER`               | `cat`  | Any tool respecting `$PAGER`                                         |
| `LESS`                | `-FX`  | `less` exits immediately if output fits one screen                   |
| `BAT_PAGER`           | `cat`  | `bat` syntax highlighter non-interactive                             |

## Why

AI agents can't interact with editors or pagers. Without this, commands like `git rebase --continue` or `git log` hang forever waiting for user input.
