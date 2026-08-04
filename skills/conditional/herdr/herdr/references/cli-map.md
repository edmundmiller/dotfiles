# Herdr CLI map

Use the installed CLI as the versioned source of truth. Run `<area> --help` before uncommon operations and `herdr api schema --json` before raw protocol work. `herdr --skill` prints the skill bundled with the installed binary. Do not run bare `herdr` for discovery; it launches or attaches the TUI.

## Selection guide

| Intent                      | Preferred command                                               |
| --------------------------- | --------------------------------------------------------------- |
| Inspect all detected agents | `herdr agent list`                                              |
| Inspect one agent           | `herdr agent get <target>`                                      |
| Read an agent transcript    | `herdr agent read <target> --source recent-unwrapped --lines N` |
| Understand status detection | `herdr agent explain <target> --json`                           |
| Prompt an agent             | `herdr agent prompt <target> <text> [--wait --timeout MS]`       |
| Wait for agent state        | `herdr agent wait <target> [--until <state>] --timeout MS`       |
| Start an agent              | `herdr agent start <name> --kind <kind> --pane <id> [-- argv…]` |
| Inspect current pane        | `herdr pane current`                                            |
| Run a shell command         | `herdr pane run <pane> <command>`                               |
| Wait for process output     | `herdr pane wait-output <pane> --match <text> --timeout MS`     |
| Bootstrap full live state   | `herdr api snapshot`                                            |
| Inspect API types           | `herdr api schema --json`                                       |

`agent start` requires an existing pane at an interactive shell prompt; it never creates layout. Arguments after `--` are passed unchanged to the agent executable.

## Output and ID rules

List/create/split/start commands return structured data. Consume the returned ID instead of predicting it. Public IDs are opaque stable handles in current syntax (`w1`, `w1:t1`, `w1:p1`); older servers and traces contain legacy forms. Closed tab and pane IDs are not reused. A pane moved into another workspace gets a new workspace-qualified ID — continue with `.result.move_result.pane.pane_id`, not the reported `.result.move_result.previous_pane_id`.

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

Agent waits observe semantic state. Without `--until`, `agent wait` and `agent prompt --wait` return on the first settled `idle`, `done`, or `blocked` state; pass `--until` only for a state-specific workflow. Focusing a tab, or targeting the pane/agent with a focus command, marks it seen; CLI reads do not. For a server/test process, wait on output or inspect process info instead. Wait commands have no default timeout; always pass `--timeout`. Server errors print JSON to stderr and exit 1; invalid CLI syntax exits 2.

## Pane reads

- `visible`: current viewport only.
- `recent`: rendered scrollback; may contain soft wraps.
- `recent-unwrapped`: joins terminal soft wraps; prefer for matching, copying, and agent transcripts.
- `detection`: the plain-text bottom-buffer snapshot Herdr uses for agent detection.
- `--format ansi` / `--ansi`: rendered TUI feedback loops only.

Pane and agent read responses report `truncated: true` when older rows were omitted. Treat a truncated read as incomplete: raise `--lines`, which is capped at 1000 (default 80) with no offset flag, so rows older than that window cannot be recovered by reading again. If it is still truncated, read a durable file/log or ask the agent to restate the result.

## Topology

- Workspace: project context and optional worktree provenance.
- Tab: related subcontext within a workspace.
- Pane: one PTY/process.
- Layout: live split tree; inspect with `herdr pane layout`. There is no layout export/apply in 0.8.0.

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
