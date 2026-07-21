# Herdr CLI map

Use the installed CLI as the versioned source of truth. Print the relevant command group before uncommon operations and run `herdr api schema --json` before raw protocol work.

## Selection guide

| Intent                      | Preferred command                                               |
| --------------------------- | --------------------------------------------------------------- |
| Inspect all detected agents | `herdr agent list`                                              |
| Inspect one live agent      | `herdr agent get <name-or-pane>`                                |
| Read an agent transcript    | `herdr agent read <target> --source recent-unwrapped --lines N` |
| Understand status detection | `herdr agent explain <target> --json`                           |
| Start in an existing pane   | `herdr agent start <name> --kind <kind> --pane <pane>`          |
| Submit a prompt             | `herdr agent prompt <target> <text> [--wait]`                   |
| Send logical UI keys        | `herdr agent send-keys <target> <key...>`                       |
| Wait for lifecycle state    | `herdr agent wait <target> --until <state> --timeout MS`        |
| Run a shell command         | `herdr pane run <pane> <command>`                               |
| Wait for process output     | `herdr pane wait-output <pane> --match <text> --timeout MS`     |
| Inspect current pane        | `herdr pane current --current`                                  |
| Bootstrap full state        | `herdr api snapshot`                                            |

## Response and ID rules

Creation, split, move, start, prompt, and wait commands return structured data. Consume returned IDs instead of predicting them.

- `workspace create` returns `.result.workspace`, `.result.tab`, and `.result.root_pane`.
- `tab create` returns `.result.tab` and `.result.root_pane`.
- `pane split` returns `.result.pane`.
- `pane move` returns the new ID at `.result.move_result.pane.pane_id` and the old value at `.result.move_result.previous_pane_id`.
- Successful `agent start`, `agent prompt`, and `agent wait` return the current agent at `.result.agent`.
- `pane wait-output` returns `.result.pane_id`, `.result.matched_line`, and `.result.read`.

Use a unique live agent name for human-facing coordination and a returned pane ID when ambiguity exists. After closes, moves, reconnects, or replacements, list state again.

## Lifecycle waits

`agent prompt --wait` submits immediately and then waits. From a non-working state it first requires a lifecycle change within five seconds; otherwise it returns `agent_prompt_stalled`.

`agent prompt --wait` and bare `agent wait` settle on `idle`, `done`, or `blocked` by default. Repeat `--until` only when a workflow requires exact states. `unknown` is never success unless explicitly requested for diagnosis.

Wait commands have no default timeout. On timeout or another server error, commands print JSON to stderr and exit 1. Invalid syntax exits 2.

## Read sources

- `visible`: current viewport.
- `recent`: rendered screen and available scrollback with soft wraps.
- `recent-unwrapped`: soft wraps joined; prefer for logs and transcripts.
- `detection`: plain-text bottom-buffer snapshot used for agent detection; available through `agent read`, not `pane read`.

Reads default to 80 rendered rows for recent sources. Use `--format ansi` only when styling is evidence.

## Topology

- Workspace: project context and optional worktree provenance.
- Tab: related subcontext within a workspace.
- Pane: one PTY/process.
- Agent: the recognized process currently occupying a pane.

Inspect topology before mutation:

```bash
herdr workspace list
herdr tab list --workspace "$HERDR_WORKSPACE_ID"
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane edges --pane "$HERDR_PANE_ID"
```
