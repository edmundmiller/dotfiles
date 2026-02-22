# @edmundmiller/pi-tasks

Task management extension for the [pi coding agent](https://github.com/badlogic/pi-mono).

Fork of [@soleone/pi-tasks](https://github.com/Soleone/pi-tasks) with beads 0.55+ support.

## Changes from upstream

- **beads adapter**: added `blocked` and `deferred` status support (bd 0.55+ has these statuses)
- **beads adapter**: list view now includes blocked tasks alongside open/in-progress

## Quick start

Point pi at this local package:

```json
// pi settings.json
{
  "extensions": ["file:///path/to/dotfiles/packages/pi-tasks"]
}
```

Toggle the Tasks UI with `ctrl + x`, or use `/tasks`.

## Usage

- Navigate up with `w` and `s` (arrows also work)
- `space` to change status (cycles: open → in-progress → blocked → deferred → closed)
- `0` to `4` to change priority
- `t` to change task type
- `f` for keyword search (title, description)
- `q` or `Esc` to go back

### List view

- `e` to edit a task
- `Enter` to work off a task
- `Tab` to insert task details in prompt and close Tasks UI
- `c` to create a new task

### Edit view

- `Tab` to switch focus between inputs
- `Enter` to save

## Backend selection

By default, the extension auto-detects the first applicable backend. If none are applicable, it falls back to `todo-md`.

Set `PI_TASKS_BACKEND` to explicitly choose a backend implementation.
Currently supported values:

- `beads`
- `todo-md`

### Beads backend

The `beads` backend integrates with [beads (bd)](https://github.com/steveyegge/beads) issue tracker.

Requires:
- `bd` CLI installed and in PATH
- `.beads/` directory in current project (run `bd init` once)

Supports all bd status values: `open`, `in_progress`, `blocked`, `deferred`, `closed`.

### TODO.md backend

The `todo-md` backend reads/writes a markdown task file (default: `TODO.md`; if `todo.md` already exists, it is used).

Optional env var:

- `PI_TASKS_TODO_PATH` — override the TODO file path
