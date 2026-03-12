# pi-non-interactive

Prevent hung agent bash commands by forcing non-interactive env defaults and blocking interactive command patterns.

## Install

```bash
pi install npm:pi-non-interactive
```

## What it does

### 1) Injects non-interactive env vars into every bash tool call

| Variable              | Value  | Effect                                                      |
| --------------------- | ------ | ----------------------------------------------------------- |
| `GIT_EDITOR`          | `true` | `git commit` / `git rebase --continue` won’t open an editor |
| `GIT_SEQUENCE_EDITOR` | `true` | prevents interactive todo-editor hangs for rebase sequences |
| `GIT_PAGER`           | `cat`  | git output won’t wait in a pager                            |
| `PAGER`               | `cat`  | generic pager safety                                        |
| `LESS`                | `-FX`  | `less` exits immediately when possible                      |
| `BAT_PAGER`           | `cat`  | `bat` output won’t block in pager                           |

### 2) Blocks commands known to hang in non-interactive runs

- `git rebase -i` / `git rebase --interactive`
- `git add -p` / `git add --patch`
- `git commit` without `-m`/`-F`/`--no-edit`
- `git commit --amend` without `--no-edit`/message
- `git mergetool`, `git difftool`, `git gui`, `git citool`
- direct TUI editor/pager commands like `vim`, `nvim`, `nano`, `man`, `less`

Each block response includes a safe non-interactive alternative.

## Recommended non-interactive git patterns

- Selective staging: `git hunks list` + `git hunks add <hunk-id>`
- Amend without editor: `git commit --amend --no-edit`
- Regular commits: `git commit -m "<message>"`
- History cleanup: `git commit --fixup <sha>` + `git rebase --autosquash <base>`

## Why

Agent bash toolcalls are non-interactive. Interactive editor/pager flows are a major source of hangs and retries (notably `git rebase -i`). This extension makes those failures explicit and recoverable.

## Rollout + measurement

1. Add package to `config/pi/settings.jsonc` (done).
2. Rebuild/apply config (`hey re` on host).
3. Track hang-signal counts in session logs before/after deploy:

```bash
bin/pi-session-hang-metrics.py --since 2026-03-01
# or machine-readable:
bin/pi-session-hang-metrics.py --since 2026-03-01 --json
```

Primary KPI: sessions with editor/pager failure signatures per week.
