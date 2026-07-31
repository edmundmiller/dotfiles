# Herdr recipes and recovery

These patterns come from official CLI behavior and recurring session-trace failures.

## Delegate to a sibling agent

1. Inspect current repo state and define a bounded handoff.
2. Split or create the shell pane; keep focus with `--no-focus`.
3. Start the agent in that pane with `herdr agent start`.
4. Submit and wait atomically with `herdr agent prompt --wait`.
5. Accept `idle`, `done`, or `blocked`, then read recent unwrapped output.
6. Review the child's changes before applying or landing them.

```bash
SPLIT=$(herdr pane split --current --direction right --no-focus)
PANE_ID=$(printf '%s' "$SPLIT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr agent start audit --kind omp --pane "$PANE_ID" --timeout 30000
herdr agent prompt "$PANE_ID" \
  "Inspect the touched tests. Report gaps; do not edit." \
  --wait --until idle --until done --until blocked --timeout 120000
herdr agent read "$PANE_ID" --source recent-unwrapped --lines 120
```

If the name is ambiguous, use the returned pane ID.

## Run and observe a service

```bash
CREATE=$(herdr pane split --current --direction right --no-focus)
# Extract pane_id from CREATE.
herdr pane run <pane-id> "npm run dev"
herdr pane wait-output <pane-id> --match "ready" --timeout 30000
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

For shell commands, use `pane run`; it submits text and Enter together. For
semantic agent prompts, use `agent prompt`.

## Preserve long-lived layouts

Export a good live layout instead of reconstructing it through sequential split assumptions:

```bash
herdr layout export
```

Apply layouts only after inspecting installed help. Layout restoration recreates structure and commands; it does not preserve live PTYs, running processes, or scrollback.
