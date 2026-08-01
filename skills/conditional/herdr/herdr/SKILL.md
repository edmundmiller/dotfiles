---
name: herdr
description: Control live Herdr workspaces, tabs, panes, agents, worktrees, plugins, and waits. Use when running inside Herdr (`HERDR_ENV=1`) to inspect sibling agents, delegate work—including dedicated Pi workspaces—run services, debug agent detection, or coordinate terminal state.
compatibility: Requires herdr 0.7.5+ with a live session (`HERDR_ENV=1`) and uv; bundled scripts are PEP 723 `uv run --script` with no third-party Python dependencies. The Pi workflow additionally needs `pi` on PATH.
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
2. **Agent CLI:** Use `herdr agent list|get|read|send-keys|prompt|rename|focus|wait|attach|start|explain` for detected agents.
3. **Resource CLI:** Use `workspace`, `tab`, `pane`, `worktree`, and `integration` commands for terminal topology and processes.
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
~/.agents/skills/herdr/scripts/agent_context.py <agent-name-or-pane-id> --lines 80
```

Use `agent explain` when status is wrong, stuck, or `unknown`; do not guess from screen text alone.

## Coordinate agents semantically

Agent start requires an **existing pane sitting at an interactive shell prompt**; it never creates layout. Create the pane first, then start the agent in it:

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
review_pane=$(printf '%s\n' "$split" | ~/.agents/skills/herdr/scripts/extract_ids.py pane)
herdr agent start reviewer --kind omp --pane "$review_pane"
herdr agent prompt reviewer "Review the current changes and report only actionable findings." \
  --wait --until done --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 100
```

Use names only when unique. Otherwise use the pane ID returned by `pane split` or a fresh `agent list` response. Agent names match `[a-z][a-z0-9_-]{0,31}` and must be unique among live agents; use `herdr agent rename <pane> <name>` to name a manually launched agent.

`agent prompt` submits the text plus an encoded Enter in one call and honors bracketed paste. `--until` requires `--wait`. From a non-working state, a lifecycle change must be observed within 5s or the call returns `agent_prompt_stalled`; `--wait` does not track turns.

State meanings: `idle` = ready for input AND its tab has been seen in the focused UI. `done` = the same ready state after background work, held until the tab gains focus (CLI reads do **not** mark a tab seen). `blocked` = an approval or question UI is up. `unknown` is not a successful completion. A status wait observes agent state, not arbitrary command completion.

## Run processes in panes

Use pane primitives for servers, tests, logs, and shells:

```bash
SPLIT=$(herdr pane split --current --direction right --no-focus)
# Parse the new pane_id from SPLIT; do not predict it.
herdr pane run <pane-id> "npm run dev"
herdr pane wait-output <pane-id> --match "ready" --timeout 30000
herdr pane read <pane-id> --source recent-unwrapped --lines 40
```

`pane wait-output` searches the selected snapshot immediately, including output that already arrived, before it polls — so it is safe for output that may have landed already. Read `recent-unwrapped` when matching or copying text so soft wraps do not corrupt it.

## Workspaces, worktrees, and layouts

Use a workspace for a project context, a tab for a subcontext, and a pane for one process. Prefer Herdr worktree commands when isolation is part of the task:

```bash
herdr worktree list
herdr worktree create --help
herdr workspace create --cwd /path/to/project --label api --no-focus
```

Inspect installed help before using less-common worktree/plugin flags; these evolve faster than the core commands.

`workspace create` also creates the first tab and its root pane — parse `.result.root_pane.pane_id` and use that pane before splitting further. Likewise `tab create` returns `.result.root_pane`.

There is no layout export/apply in 0.7.5. Capture `herdr pane layout` output for reference and script `workspace create`/`pane split` sequences that parse returned IDs:

```bash
herdr pane layout --current
```

## Input rules

- Use `agent prompt` for agent prompts (submits text plus encoded Enter in one call; honors bracketed paste).
- Use `pane run` for shell command text followed by Enter.
- Use `pane send-text` plus `pane send-keys … enter` for literal TUI input when no agent adapter applies.
- Pass key combos such as `ctrl+h`, `shift+tab`, or named punctuation. Do not pass configuration strings such as `prefix+]` to `send-keys`.
- Use `agent send-keys` for agent UI interaction (`esc`, `up`, `enter`, `ctrl+c`; `escape` aliases `esc`). Pane input targets the terminal regardless of occupant; agent input is rejected if the agent no longer controls the pane.

## Recovery

- Re-read IDs after closes, moves, or reconnects.
- If a command reports an unsupported flag, inspect installed `--help`; do not continue from stale examples.
- If config changed but behavior did not, run `herdr server reload-config` and inspect diagnostics.
- If agent status is wrong, run `herdr agent explain <target> --json` before changing detection rules.
- If an output wait times out, read recent output and agent state before retrying.
- If a helper cannot reach Herdr, verify `HERDR_SOCKET_PATH` and `HERDR_ENV`; never scan unrelated sockets.

### Known pitfalls (from session traces)

- Nonexistent guessed commands: `herdr agents`, `herdr agent status`, `herdr pane stop`, `herdr worktree sessions`, `herdr wait`, `herdr layout` — run `herdr <group> --help` instead of guessing.
- Opening a workspace or worktree auto-creates panes; run `herdr agent list` and reuse an existing idle agent before `agent start`, to avoid duplicate agents in one workspace.
- On `agent wait` timeout (exit 1, JSON on stderr): run `herdr agent read <t> --source recent-unwrapped --lines 80` and `herdr agent explain <t> --json` before retrying; never re-issue the same wait blind. Always pass `--timeout` — waits are indefinite by default.
- Full-screen agents may render on the alternate screen, so those rows never enter scrollback: if a larger `--lines` adds no text, read `--source visible` after scrolling in the agent, or (fallback only) ask the agent to write its full answer to a temp file and read that.
- After `herdr pane rename`, also run `herdr tab rename` — stale tab labels misdirect later targeting; trust `agent list` cwd/session fields over labels.

## Bundled resources

- `references/cli-map.md` — high-level command selection and response rules.
- `references/recipes.md` — delegation, service, layout, and failure-recovery recipes.
- `references/pi-workspace.md` — dedicated Pi workspace delegation and handoff workflow.
- `scripts/start_pi_workspace.py` — create a workspace, launch Pi, and submit a prompt file.
- `scripts/send_prompt_to_pane.py` — submit a prompt file to an existing pane.
- `scripts/write_handoff_prompt.py` — generate a structured child-agent prompt.
- `scripts/monitor_pane.py` and `scripts/extract_ids.py` — inspect delegated work and parse live IDs.
- `scripts/agent_context.py` — bounded JSON snapshot of one agent's metadata, recent output, and detection explanation.
- Upstream reference: https://herdr.dev/docs/agent-automation/ — official automation primitives for herdr 0.7.5.
