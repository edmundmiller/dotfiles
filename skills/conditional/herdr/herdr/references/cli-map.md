# Herdr CLI map

Use the installed CLI as the versioned source of truth. Run `<area> --help` before uncommon operations and `herdr api schema --json` before raw protocol work.

## Selection guide

| Intent                      | Preferred command                                               |
| --------------------------- | --------------------------------------------------------------- |
| Inspect all detected agents | `herdr agent list`                                              |
| Inspect one agent           | `herdr agent get <target>`                                      |
| Read an agent transcript    | `herdr agent read <target> --source recent-unwrapped --lines N` |
| Understand status detection | `herdr agent explain <target> --json`                           |
| Prompt an agent             | `herdr agent prompt <target> <text> [--wait --until <state>]`   |
| Wait for agent state        | `herdr agent wait <target> --until <state> --timeout MS`        |
| Start an agent              | `herdr agent start <name> --kind <kind> --pane <id> [-- argv…]` |
| Inspect current pane        | `herdr pane current`                                            |
| Run a shell command         | `herdr pane run <pane> <command>`                               |
| Wait for process output     | `herdr pane wait-output <pane> --match <text> --timeout MS`     |
| Bootstrap full live state   | `herdr api snapshot`                                            |
| Inspect API types           | `herdr api schema --json`                                       |

`agent start` requires an existing pane at an interactive shell prompt; it never creates layout. Arguments after `--` are passed unchanged to the agent executable.

## Output and ID rules

List/create/split/start commands return structured data. Consume the returned ID instead of predicting it. IDs can use current public syntax such as `w1:p1`, while older servers and traces contain legacy forms. Both are opaque handles.

Prefer:

- `--current` when the operation supports it.
- Unique agent names for human-facing coordination.
- Returned pane IDs when names collide.
- A fresh list/snapshot after closing, moving, reconnecting, or replacing resources.

JSON key paths for chained automation:

- `workspace create` → `.result.root_pane.pane_id`
- `tab create` → `.result.root_pane.pane_id`
- `pane split` → `.result.pane.pane_id`
- `pane move` → `.result.move_result.pane.pane_id`
- `pane wait-output` → `.result.matched_line` (plus `.result.pane_id`, `.result.read`)
- `agent start|prompt|wait` → `.result.agent`

`scripts/extract_ids.py workspace|tab|pane` reads this JSON on stdin and prints the id. Prefer it over hand-written key paths: `pane` transparently accepts both `root_pane` (workspace/tab create) and `pane` (pane split) shapes.

## Agent states

- `idle`: ready for input AND its tab has been seen in the focused UI.
- `working`: actively processing.
- `blocked`: an approval or question UI is waiting on input.
- `done`: ready after background work, held until the tab gains focus; CLI reads do not mark a tab seen.
- `unknown`: no authoritative state — not a successful completion.

Agent waits observe semantic state. For a server/test process, wait on output or inspect process info instead. Wait commands have no default timeout; always pass `--timeout`. Server errors print JSON to stderr and exit 1; invalid CLI syntax exits 2.

## Pane reads

- `visible`: current viewport only.
- `recent`: rendered scrollback; may contain soft wraps.
- `recent-unwrapped`: joins terminal soft wraps; prefer for matching, copying, and agent transcripts.
- `--format ansi` / `--ansi`: rendered TUI feedback loops only.

## Topology

- Workspace: project context and optional worktree provenance.
- Tab: related subcontext within a workspace.
- Pane: one PTY/process.
- Layout: live split tree; inspect with `herdr pane layout`. There is no layout export/apply in 0.7.5.

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
herdr plugin --help
herdr integration --help
```

Use raw socket methods only when CLI wrappers cannot express the operation or a long-lived event subscription is required.
