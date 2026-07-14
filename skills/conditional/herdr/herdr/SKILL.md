---
name: herdr
description: Control live Herdr workspaces, tabs, panes, agents, worktrees, layouts, plugins, and waits. Use when running inside Herdr (`HERDR_ENV=1`) to inspect sibling agents, delegate work, run services, debug agent detection, or coordinate terminal state.
---

# Herdr

Control the current Herdr session through its high-level CLI wrappers. Prefer semantic `agent` commands for agent lifecycle and communication; use pane commands for shells, processes, terminal input, and output.

## Guard

Check `HERDR_ENV=1` before controlling a session. If absent, report that the current pane is not Herdr-managed and stop. Do not infer the focused pane from outside Herdr.

```bash
test "${HERDR_ENV:-}" = 1
```

Treat Herdr IDs as live handles, not durable identifiers. Parse IDs from command responses or use `--current`; never hard-code example IDs into automation.

## Choose the narrowest surface

1. **Harness resource:** When `herdr://` reads are supported, inspect `herdr://status`, `herdr://snapshot`, `herdr://workspaces`, `herdr://tabs?workspace=…`, `herdr://panes?workspace=…`, or `herdr://pane/<id>?source=recent&lines=80`. This avoids shell parsing.
2. **Agent CLI:** Use `herdr agent list|get|read|send|wait|start|focus|explain` for detected agents.
3. **Resource CLI:** Use `workspace`, `tab`, `pane`, `worktree`, `layout`, and `plugin` commands for terminal topology and processes.
4. **Raw API:** Use only for protocol clients or event subscriptions. Inspect the installed schema first with `herdr api schema --json`.

Read `references/cli-map.md` for the command map and `references/recipes.md` for trace-tested coordination and recovery patterns.

## Inspect before acting

Start from live state:

```bash
herdr agent list
herdr pane current
herdr workspace list
```

For one agent, gather semantic state, recent output, and detection evidence:

```bash
python3 ~/.agents/skills/herdr/scripts/agent_context.py <agent-name-or-pane-id> --lines 80
```

Use `agent explain` when status is wrong, stuck, or `unknown`; do not guess from screen text alone.

## Coordinate agents semantically

Start an agent in a managed pane and capture its returned pane ID:

```bash
START=$(herdr agent start reviewer --cwd "$PWD" --split right --no-focus -- omp)
PANE_ID=$(printf '%s' "$START" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')
```

Wait until the agent is ready. `agent send` writes literal text; submit it with Enter through that pane ID. Use the lower-level status waiter when the UI-specific `done` state matters:

```bash
herdr agent wait "$PANE_ID" --status idle --timeout 30000
herdr agent send "$PANE_ID" "Review the current changes and report only actionable findings."
herdr pane send-keys "$PANE_ID" enter
herdr wait agent-status "$PANE_ID" --status done --timeout 120000
herdr agent read "$PANE_ID" --source recent-unwrapped --lines 100
```

Use names only when unique. Otherwise use the pane ID returned by `agent start` or a fresh `agent list` response.

`done` means the agent finished but its pane has not been viewed. `idle` means it is ready for input. A status wait observes agent state, not arbitrary command completion.

## Run processes in panes

Use pane primitives for servers, tests, logs, and shells:

```bash
SPLIT=$(herdr pane split --current --direction right --no-focus)
# Parse the new pane_id from SPLIT; do not predict it.
herdr pane run <pane-id> "npm run dev"
herdr wait output <pane-id> --match "ready" --timeout 30000
herdr pane read <pane-id> --source recent-unwrapped --lines 40
```

Use `pane read` for output that may already exist. Use `wait output` only for expected future output. Read `recent-unwrapped` when matching or copying text so soft wraps do not corrupt it.

## Workspaces, worktrees, and layouts

Use a workspace for a project context, a tab for a subcontext, and a pane for one process. Prefer Herdr worktree commands when isolation is part of the task:

```bash
herdr worktree list
herdr worktree create --help
herdr workspace create --cwd /path/to/project --label api --no-focus
```

Inspect installed help before using less-common worktree/plugin/layout flags; these evolve faster than the core commands.

For repeatable multi-pane setups, export/apply layouts rather than replaying fragile split sequences:

```bash
herdr layout export
herdr pane layout --current
```

## Input rules

- Use `agent send` for agent prompts.
- Use `pane run` for shell command text followed by Enter.
- Use `pane send-text` plus `pane send-keys … enter` for literal TUI input when no agent adapter applies.
- Pass key combos such as `ctrl+h`, `shift+tab`, or named punctuation. Do not pass configuration strings such as `prefix+]` to `send-keys`.

## Recovery

- Re-read IDs after closes, moves, or reconnects.
- If a command reports an unsupported flag, inspect installed `--help`; do not continue from stale examples.
- If config changed but behavior did not, run `herdr server reload-config` and inspect diagnostics.
- If agent status is wrong, run `herdr agent explain <target> --json` before changing detection rules.
- If an output wait times out, read recent output and agent state before retrying.
- If a helper cannot reach Herdr, verify `HERDR_SOCKET_PATH` and `HERDR_ENV`; never scan unrelated sockets.

## Bundled resources

- `references/cli-map.md` — high-level command selection and response rules.
- `references/recipes.md` — delegation, service, layout, and failure-recovery recipes.
- `scripts/agent_context.py` — bounded JSON snapshot of one agent's metadata, recent output, and detection explanation.
