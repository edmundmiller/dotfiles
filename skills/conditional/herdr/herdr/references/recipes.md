# Herdr recipes and recovery

These patterns follow Herdr 0.7.5's official agent-automation contract.

## Delegate to a sibling agent

1. Confirm `HERDR_ENV=1`, inspect repo state, and define a bounded handoff.
2. Inspect pane geometry, split without taking focus, and parse the returned pane ID.
3. Start the supported agent in that existing shell pane.
4. Submit the prompt atomically with `agent prompt`.
5. Inspect the returned settled state and recent unwrapped output.
6. Review the child's work before applying, merging, or landing it.

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane_id=$(printf '%s\n' "$split" | python3 ~/.agents/skills/herdr/scripts/extract_ids.py pane)
herdr agent start audit --kind codex --pane "$pane_id"
herdr agent prompt audit "Inspect the touched tests. Report gaps; do not edit." --wait --timeout 120000
herdr agent read audit --source recent-unwrapped --lines 120
```

`agent start` already waits for the agent to become ready. Do not add an idle wait before the first prompt.

## Run and observe a service

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane_id=$(printf '%s\n' "$split" | python3 ~/.agents/skills/herdr/scripts/extract_ids.py pane)
herdr pane run "$pane_id" "npm run dev"
herdr pane wait-output "$pane_id" --match "ready" --timeout 30000
herdr pane read "$pane_id" --source recent-unwrapped --lines 40
```

On timeout, read output before waiting again. The process may have failed before emitting the marker, or the marker may differ.

## Debug incorrect agent state

```bash
python3 ~/.agents/skills/herdr/scripts/agent_context.py <target> --lines 100
```

Metadata identifies the resolved agent and pane, recent output shows visible behavior, and explain output shows lifecycle authority and matching evidence. Fix detection only when explanation proves the rule is wrong.

## Interact with a blocked agent

```bash
herdr agent wait reviewer --until blocked --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 80
herdr agent send-keys reviewer esc
```

Never infer which answer or approval to send from `blocked` alone. Read the visible prompt and preserve the user's authority boundary.

## Recover after stale examples

Symptoms include `unknown option`, missing `--kind` or `--pane`, use of removed `agent send`, and top-level `wait` commands.

1. Stop issuing variants.
2. Print the installed command group.
3. Re-list live resources.
4. Use current flags and returned IDs.
5. Verify the resulting agent, pane, or output—not only exit status.

## Reload configuration safely

```bash
herdr server reload-config
```

Inspect diagnostics, then exercise the changed behavior. A file write or `reload_needed` field alone is not proof.

## Use raw pane input only intentionally

For a non-agent TUI with no semantic adapter:

```bash
herdr pane send-text <pane-id> "literal text"
herdr pane send-keys <pane-id> enter
```

For a shell command use `pane run`. For a recognized coding agent use `agent prompt` or `agent send-keys`.
