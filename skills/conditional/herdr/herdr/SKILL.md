---
name: herdr
description: "Control Herdr, a terminal multiplexer for coding agents. Use only when the user explicitly mentions Herdr or asks to use Herdr to inspect or control panes, tabs, workspaces, commands, or another agent. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work. Requires HERDR_ENV=1."
---

# Herdr

Herdr organizes terminals into workspaces, tabs, and panes, recognizes coding agents running inside panes, and exposes the current session through the `herdr` CLI.

## Guard the session boundary

Before any control command, verify that this agent is running inside a Herdr-managed pane:

```bash
test "${HERDR_ENV:-}" = 1
```

If the check fails, say that this pane is not Herdr-managed and stop. Do not infer or control the focused Herdr session from outside Herdr.

Treat Herdr IDs as live opaque handles. Parse them from command responses or use `--current`; never predict them from examples or sidebar order.

## Learn the installed CLI

The installed binary is the versioned authority. Start with `herdr --help`, then print the relevant command group without a nested subcommand:

```bash
herdr agent
herdr pane
herdr workspace
herdr tab
herdr worktree
herdr plugin
herdr integration
```

Do not run bare `herdr` for discovery; it launches or attaches the TUI. Do not probe a mutating nested command by omitting arguments. Commands such as `herdr workspace create` can execute with defaults.

Use `herdr api schema --json` before raw protocol work. Prefer `herdr://` resources when the current harness exposes them.

## Choose the correct primitive

- Layout commands create and organize workspaces, tabs, and pane topology.
- Pane commands control raw terminals, shells, tests, servers, input, and output.
- Agent commands control the recognized coding agent currently occupying a pane.

A pane exists whether or not it contains an agent. `agent start` requires an existing available shell pane and never creates, splits, or moves layout. The pane must be at its interactive prompt with no foreground command, editor, or agent running.

Agent commands accept only a unique live name or the pane ID currently hosting that agent. Names must match `[a-z][a-z0-9_-]{0,31}` and are cleared when the occupant exits, is released, or is replaced.

## Inspect live state

Prefer caller context over another client's focus:

```bash
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
herdr pane current --current
herdr workspace list
herdr tab list --workspace "$HERDR_WORKSPACE_ID"
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
herdr agent list
```

For one agent, gather bounded semantic state, recent output, and detection evidence:

```bash
python3 ~/.agents/skills/herdr/scripts/agent_context.py <agent-name-or-pane-id> --lines 80
```

Use `agent explain` when status is wrong, stuck, or `unknown`. Do not infer lifecycle state from screen text alone.

## Start and coordinate an agent

Default to a sibling pane in the current tab and current working directory. Create a different workspace, tab, worktree, or cwd only when the user requests that topology or location.

Inspect layout before choosing a split direction, preserve the caller's cwd, and keep focus unchanged for background work:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane_id=$(printf '%s\n' "$split" | python3 ~/.agents/skills/herdr/scripts/extract_ids.py pane)
```

Use `down` instead of `right` for a narrow or tall pane. Start the requested supported agent in the returned shell pane:

```bash
herdr agent start reviewer --kind codex --pane "$pane_id"
```

Native agent arguments follow `--`. `agent start` returns only after Herdr detects the expected agent and considers it ready for interactive input:

```bash
herdr agent start reviewer --kind codex --pane "$pane_id" -- <agent-args...>
```

Submit work atomically through the agent surface:

```bash
herdr agent prompt reviewer "Review the current diff and report only actionable findings." --wait --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 120
```

`agent prompt` submits text plus encoded Enter while honoring bracketed-paste mode. `--wait` accepts the first settled `idle`, `done`, or `blocked` state by default. It observes lifecycle, not a particular turn; prompting an already-working agent can settle when that active turn finishes.

A prompt sent from a non-working state must produce an observed lifecycle change within five seconds or it returns `agent_prompt_stalled`. Inspect state and output before retrying.

Use exact states only when the distinction matters:

```bash
herdr agent wait reviewer --until blocked --timeout 120000
herdr agent send-keys reviewer esc
```

## Understand agent states

- `working`: actively processing.
- `blocked`: a recognized approval or question UI needs input.
- `idle`: ready for input and already seen in the focused Herdr UI.
- `done`: ready after unseen background work; CLI reads do not mark it seen.
- `unknown`: present but not classified confidently; never proof of completion.

If a wait fails or returns `blocked`, inspect `agent get` and `agent read` before deciding what input to send.

## Run ordinary processes in panes

Use pane primitives for shells, tests, servers, and watchers:

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane_id=$(printf '%s\n' "$split" | python3 ~/.agents/skills/herdr/scripts/extract_ids.py pane)
herdr pane run "$pane_id" "just test"
herdr pane wait-output "$pane_id" --match "test result" --timeout 120000
herdr pane read "$pane_id" --source recent-unwrapped --lines 120
```

`pane wait-output` searches the current snapshot immediately, so already-present text can match. Use `--match` for a literal substring and `--regex` for a Rust regular expression.

Use `visible`, `recent`, or `recent-unwrapped` with `pane read`; use `agent read --source detection` for the detection buffer. Preserve ANSI only when terminal styling is evidence. Alternate-screen agents may not retain disappeared response rows in host scrollback; enlarge the pane, request concise output, use the agent transcript, or scroll inside the agent and read `visible`.

## Handle IDs and moves

Creation responses expose the next IDs:

- `workspace create`: `.result.workspace`, `.result.tab`, `.result.root_pane`
- `tab create`: `.result.tab`, `.result.root_pane`
- `pane split`: `.result.pane`

Moving a pane changes its workspace-qualified pane ID. Continue with `.result.move_result.pane.pane_id` or the live agent name. A wait already targeting the previous ID ends with `agent_not_running`.

## Safety and recovery

- Use `--no-focus` unless the user asked to switch context.
- Do not close workspaces, tabs, panes, or sessions you did not create unless explicitly asked.
- Never stop or kill the main Herdr process unless the user explicitly intends to stop the server and its pane processes.
- Use named test sessions for isolated server experiments.
- After an unsupported flag, inspect installed command help and re-list state before retrying.
- After config changes, run `herdr server reload-config`, inspect diagnostics, and exercise the changed behavior.
- CLI server errors are JSON on stderr with exit status 1; CLI syntax errors exit with status 2.

## Bundled resources

- `references/cli-map.md` — compact command and response map.
- `references/recipes.md` — trace-tested coordination and recovery patterns.
- `references/pi-workspace.md` — dedicated Pi workspace workflow.
- `scripts/start_pi_workspace.py` — create a workspace, start Pi in its root pane, and submit a prompt atomically.
- `scripts/send_prompt_to_pane.py` — start or prompt Pi in an existing pane.
- `scripts/monitor_pane.py` and `scripts/agent_context.py` — inspect semantic state and bounded output.
- `scripts/extract_ids.py` — parse creation, split, and moved-pane IDs.
- `scripts/write_handoff_prompt.py` — generate a structured child-agent prompt.
