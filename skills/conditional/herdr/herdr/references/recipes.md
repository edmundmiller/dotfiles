# Herdr recipes and recovery

These patterns come from official CLI behavior and recurring session-trace failures.

## Delegate to a sibling agent

1. Inspect current repo state and define a bounded handoff.
2. Start the agent with `herdr agent start`; keep focus with `--no-focus`.
3. Wait for `idle` before sending a long prompt.
4. Send literal prompt text with `herdr agent send`, then submit Enter to the returned pane ID.
5. Wait for `done` with `herdr wait agent-status`, then read recent unwrapped output.
6. Review the child's changes before applying or landing them.

```bash
START=$(herdr agent start audit --cwd "$PWD" --split right --no-focus -- omp)
PANE_ID=$(printf '%s' "$START" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')
herdr agent wait "$PANE_ID" --status idle --timeout 30000
herdr agent send "$PANE_ID" "Inspect the touched tests. Report gaps; do not edit."
herdr pane send-keys "$PANE_ID" enter
herdr wait agent-status "$PANE_ID" --status done --timeout 120000
herdr agent read "$PANE_ID" --source recent-unwrapped --lines 120
```

If the name is ambiguous, use the returned pane ID.

## Run and observe a service

```bash
CREATE=$(herdr pane split --current --direction right --no-focus)
# Extract pane_id from CREATE.
herdr pane run <pane-id> "npm run dev"
herdr wait output <pane-id> --match "ready" --timeout 30000
herdr pane read <pane-id> --source recent-unwrapped --lines 40
```

On timeout, read output before waiting again. The process may have failed before emitting the marker.

## Debug incorrect agent status

```bash
python3 ~/.agents/skills/herdr/scripts/agent_context.py <target> --lines 100
```

Interpret the combined output:

- Metadata identifies the selected agent/pane.
- Recent output shows visible behavior.
- Explanation shows the manifest, rule evidence, lifecycle authority, and skip reason.

Fix detection only when explanation proves the rule is wrong. Do not infer status solely from prompts or spinners.

## Recover after stale examples

Symptoms from traces include `unknown option: --focus`, missing required `--direction`, and guessed pane IDs selecting the wrong pane.

Recovery:

1. Stop issuing variants.
2. Run the installed command's `--help`.
3. Re-list/snapshot resources.
4. Use current flags and parse returned IDs.
5. Verify the resulting pane/tab/workspace, not merely command exit status.

## Reload configuration safely

After changing Herdr config:

```bash
herdr server reload-config
```

Inspect returned diagnostics and then exercise the changed behavior. A file write or `reload_needed` field alone is not proof.

## Use pane input only as fallback

For a TUI that has no Herdr agent adapter:

```bash
herdr pane send-text <pane-id> "literal text"
herdr pane send-keys <pane-id> enter
```

For shell commands, use `pane run`; it submits text and Enter together. For semantic agent prompts, use `agent send`.

## Preserve long-lived layouts

Export a good live layout instead of reconstructing it through sequential split assumptions:

```bash
herdr layout export
```

Apply layouts only after inspecting installed help. Layout restoration recreates structure and commands; it does not preserve live PTYs, running processes, or scrollback.
