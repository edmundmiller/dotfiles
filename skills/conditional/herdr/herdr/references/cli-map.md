# Herdr CLI map

Use the installed CLI as the versioned source of truth. Run `<area> --help` before uncommon operations and `herdr api schema --json` before raw protocol work.

## Selection guide

| Intent                      | Preferred command                                               |
| --------------------------- | --------------------------------------------------------------- |
| Inspect all detected agents | `herdr agent list`                                              |
| Inspect one agent           | `herdr agent get <target>`                                      |
| Read an agent transcript    | `herdr agent read <target> --source recent-unwrapped --lines N` |
| Understand status detection | `herdr agent explain <target> --json`                           |
| Prompt an agent             | `herdr agent send <target> <text>`                              |
| Wait for agent state        | `herdr agent wait <target> --status <state> --timeout MS`       |
| Start an agent              | `herdr agent start <name> … -- <argv…>`                         |
| Inspect current pane        | `herdr pane current`                                            |
| Run a shell command         | `herdr pane run <pane> <command>`                               |
| Wait for process output     | `herdr wait output <pane> --match <text> --timeout MS`          |
| Bootstrap full live state   | `herdr api snapshot`                                            |
| Inspect API types           | `herdr api schema --json`                                       |

## Output and ID rules

List/create/split/start commands return structured data. Consume the returned ID instead of predicting it. IDs can use current public syntax such as `w1:p1`, while older servers and traces contain legacy forms. Both are opaque handles.

Prefer:

- `--current` when the operation supports it.
- Unique agent names for human-facing coordination.
- Returned pane IDs when names collide.
- A fresh list/snapshot after closing, moving, reconnecting, or replacing resources.

## Agent states

- `idle`: ready for input.
- `working`: actively processing.
- `blocked`: waiting on external input or permission.
- `done`: finished and not yet viewed.
- `unknown`: no authoritative state.

Agent waits observe semantic state. For a server/test process, wait on output or inspect process info instead.

## Pane reads

- `visible`: current viewport only.
- `recent`: rendered scrollback; may contain soft wraps.
- `recent-unwrapped`: joins terminal soft wraps; prefer for matching, copying, and agent transcripts.
- `--format ansi` / `--ansi`: rendered TUI feedback loops only.

## Topology

- Workspace: project context and optional worktree provenance.
- Tab: related subcontext within a workspace.
- Pane: one PTY/process.
- Layout: portable split tree; export/apply for repeatable setups.

Inspect topology before mutation:

```bash
herdr workspace list
herdr tab list
herdr pane layout --current
herdr pane edges --current
```

## Advanced areas

Use installed help rather than copied flag inventories:

```bash
herdr worktree --help
herdr layout --help
herdr plugin --help
herdr integration --help
```

Use raw socket methods only when CLI wrappers cannot express the operation or a long-lived event subscription is required.
