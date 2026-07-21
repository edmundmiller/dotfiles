# Pi workspace delegation

Use this workflow only when the user explicitly asks for a new Herdr workspace or Pi session. It requires `HERDR_ENV=1`; do not use it as an implicit substitute for ordinary local work or generic parallelism.

## Contract

1. Inspect the parent repo and identify unrelated dirty files.
2. Write a bounded handoff prompt without secrets.
3. Create the requested workspace; use its returned root pane.
4. Start Pi in that existing shell pane through `agent start`.
5. Submit the prompt atomically through `agent prompt`.
6. Record the returned workspace, pane, and agent name.
7. Monitor lifecycle and output through agent commands.
8. Review child output and changes before applying or landing them.

`agent start` waits for Pi to be detected and ready. Do not run Pi with `pane run`, add a redundant idle wait, or submit a prompt as raw terminal text.

## Helpers

The skill ships dependency-free helpers:

- `write_handoff_prompt.py` builds a structured prompt file.
- `start_pi_workspace.py` creates a workspace, starts Pi in the returned root pane, and prompts it.
- `send_prompt_to_pane.py` starts or prompts Pi in an existing available pane.
- `monitor_pane.py` waits for semantic state and prints bounded output.
- `extract_ids.py` parses workspace, tab, split-pane, and moved-pane IDs.

Create a prompt and launch Pi without stealing focus:

```bash
prompt_file=$(mktemp -t pi-handoff.XXXXXX.md)
python3 ~/.agents/skills/herdr/scripts/write_handoff_prompt.py \
  --cwd /path/to/repo \
  --goal "Implement or investigate the bounded task." \
  --context "Known fact." \
  --read-first "docs/adr/example.md" \
  --guardrail "Keep changes small and reviewable." \
  --guardrail "Do not commit unless explicitly asked." \
  --validation "Run focused tests." \
  --dirty-worktree-warning \
  --output "$prompt_file"

launch_json=$(python3 ~/.agents/skills/herdr/scripts/start_pi_workspace.py \
  --cwd /path/to/repo \
  --label "Short task label" \
  --prompt-file "$prompt_file")

pane_id=$(printf '%s\n' "$launch_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["pane_id"])')
agent_name=$(printf '%s\n' "$launch_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["agent_name"])')
```

The helper defaults to `--no-focus` and derives a unique Pi name from the returned pane ID. Use `--focus` only when the user asked to switch context. Use `--agent-name` when a human-readable unique name is important and `--startup-timeout-ms` when startup needs more than 30 seconds.

Monitor the child:

```bash
python3 ~/.agents/skills/herdr/scripts/monitor_pane.py \
  --pane "$pane_id" \
  --wait-status done \
  --source recent-unwrapped \
  --lines 100
```

If the child becomes `blocked`, read its output before steering. If the wait times out, the helper still reads recent output and returns nonzero.

## Existing-pane variant

The target pane must be an available interactive shell:

```bash
split=$(herdr pane split --current --direction right --cwd /path/to/repo --no-focus)
pane_id=$(printf '%s\n' "$split" | python3 ~/.agents/skills/herdr/scripts/extract_ids.py pane)
python3 ~/.agents/skills/herdr/scripts/send_prompt_to_pane.py \
  --pane "$pane_id" \
  --start-pi \
  --prompt-file "$prompt_file"
```

Without `--start-pi`, the helper resolves the current live agent by pane ID and submits the prompt. Pass `--agent-name` when the pane's agent already has a unique name you want to preserve in logs.

## Manual recipe

If the helpers are unavailable:

```bash
created=$(herdr workspace create \
  --cwd /path/to/repo \
  --label "Short task label" \
  --no-focus)

pane_id=$(printf '%s\n' "$created" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
agent_name="pi-$(printf '%s' "$pane_id" | tr ':.' '--')"

herdr agent start "$agent_name" --kind pi --pane "$pane_id"
herdr agent prompt "$agent_name" "$(<"$prompt_file")"
herdr agent get "$agent_name"
```

Monitor later with exact lifecycle state only when needed:

```bash
herdr agent wait "$agent_name" --until done --timeout 120000
herdr agent read "$agent_name" --source recent-unwrapped --lines 120
```

## Fallback after a tmux launcher failure

If a tmux side-agent launcher cannot find a tmux session and the current pane already has `HERDR_ENV=1`, preserve the same bounded prompt and use the helper above. Do not create a duplicate issue or silently broaden the task.

If `HERDR_ENV` is absent, stop and report that the current pane is not Herdr-managed. Launching or targeting an unrelated Herdr session from outside would violate the session boundary.

## Smoke test

Run a smoke test only in a disposable workspace and only when creating that workspace is authorized:

```bash
tmp_repo=$(mktemp -d)
git -C "$tmp_repo" init -q
prompt_file="$tmp_repo/smoke-prompt.md"
printf '%s\n' \
  'Do not edit files.' \
  'Reply with HERDR_PI_SMOKE_RECEIVED, then stop.' >"$prompt_file"

launch_json=$(python3 ~/.agents/skills/herdr/scripts/start_pi_workspace.py \
  --cwd "$tmp_repo" \
  --label "pi smoke" \
  --prompt-file "$prompt_file")
pane_id=$(printf '%s\n' "$launch_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["pane_id"])')

herdr pane wait-output "$pane_id" --match HERDR_PI_SMOKE_RECEIVED --lines 120 --timeout 180000
herdr agent read "$pane_id" --source recent-unwrapped --lines 120
```

Close only the disposable workspace or pane you created, and only after reviewing the output.

## Handoff checklist

- Exact repo path and branch/worktree assumptions.
- Specific goal and non-goals.
- Files or docs to read first.
- Existing decisions and unrelated dirt.
- Safety constraints and forbidden mutations.
- Focused validation commands.
- Expected final report: files changed, checks, blockers, and remaining risks.
