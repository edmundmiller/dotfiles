# @edmundmiller/pi-beads

pi extension for [beads (bd)](https://github.com/steveyegge/beads) task management.

Fork of [@soleone/pi-tasks](https://github.com/Soleone/pi-tasks) stripped down to beads-only, with bd 0.55+ support.

## Changes from upstream

- **beads-only**: removed todo-md adapter and generic resolver
- **bd 0.55+**: added `blocked` and `deferred` status support
- **list view**: includes blocked tasks alongside open/in-progress

## Requirements

- `bd` CLI in PATH
- `.beads/` directory in project (run `bd init` once)

## Quick start

```json
{ "extensions": ["~/.config/dotfiles/packages/pi-beads"] }
```

Toggle with `ctrl+x` or `/tasks`.

## Keybindings

**List view**

| Key       | Action                                                          |
| --------- | --------------------------------------------------------------- |
| `w` / `s` | Navigate                                                        |
| `space`   | Cycle status (open → in-progress → blocked → deferred → closed) |
| `0`–`4`   | Set priority                                                    |
| `t`       | Cycle type                                                      |
| `e` / `→` | Edit task                                                       |
| `enter`   | Send task to prompt                                             |
| `tab`     | Insert task ref and close                                       |
| `c`       | Create task                                                     |
| `f`       | Search/filter                                                   |
| `esc`     | Back / clear filter                                             |

**Edit view**

| Key     | Action                              |
| ------- | ----------------------------------- |
| `tab`   | Switch focus (title ↔ description) |
| `enter` | Save                                |
| `esc`   | Back to nav                         |
