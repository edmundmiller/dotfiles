---
name: herdr-pi-workspace
description: "Create a Herdr workspace/pane for delegated Pi work, especially when tmux side-agent launch/agent-start is unavailable. Starts pi, waits until ready, sends a structured handoff prompt, and monitors the child pane."
---

# Herdr Pi Workspace Handoff

Use this skill to delegate work to a sibling Pi session through Herdr. It is the preferred fallback when the tmux-based side-agent launcher is unavailable (for example, `agent-start` fails with `Failed to determine current tmux session`).

## When to use

- The user asks to "start a new Herdr workspace/space" for a task.
- The user asks to "kick off a Pi session" in a repo.
- `agent-start` or another tmux side-agent launcher cannot find a tmux session.
- You want a sibling Pi agent to implement or investigate work while preserving your current context.

## Preferred Herdr-backed delegation pattern

1. Inspect the parent repo state (`git status --short`) and identify unrelated dirty files.
2. Write a structured handoff prompt to a temp file.
3. Create a Herdr workspace (or reuse/split an existing pane) in the target repo.
4. Start `pi` in that pane.
5. Wait for the Pi agent status to become `idle` (best effort).
6. Send the handoff prompt into the Pi TUI and press Enter.
7. Record the returned `workspace_id`/`pane_id` and monitor that pane until the child reports back.
8. Review child output before applying/merging/committing any work.

Use a two-step launch for long prompts: start `pi`, wait until it is ready, then send the prompt. Avoid `pi "$(cat prompt.md)"` for large handoffs because TUI startup prompt submission can be unreliable.

## Principles

- Create a concise but complete handoff prompt before launching Pi.
- Include repo path, goal, known context, constraints, guardrails, and expected final summary.
- Tell the child Pi to inspect `git status --short` before editing.
- Warn about unrelated dirty files when you know they exist.
- Tell the child how to report back: changed files, validation, risks/TODOs, and whether it needs parent review.
- Avoid putting secrets or tokens in the prompt.
- Prefer small, reviewable child tasks; do not let the child commit unless the user asked for that explicitly.

## Scripts

The skill includes small dependency-free Python helpers in `scripts/`:

- `write_handoff_prompt.py` — generate a structured handoff prompt file from arguments.
- `start_pi_workspace.py` — create a Herdr workspace, launch Pi, wait until ready, and submit a prompt file.
- `send_prompt_to_pane.py` — submit a prompt file to an existing Herdr pane, optionally starting Pi first.
- `monitor_pane.py` — inspect a pane, optionally wait for an agent status, and print recent output.
- `extract_ids.py` — parse Herdr JSON from stdin and print workspace/tab/pane ids for shell pipelines.

## Preferred script workflow

Use the included helpers when available. They handle workspace creation, pane-id parsing, Pi startup, prompt submission, and monitoring.

```bash
PROMPT_FILE=$(mktemp -t pi-handoff.XXXXXX.md)
python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/write_handoff_prompt.py \
  --cwd /path/to/repo \
  --goal "Implement/investigate ..." \
  --context "Known fact ..." \
  --read-first "docs/adr/example.md" \
  --guardrail "Keep changes small and reviewable." \
  --guardrail "Do not commit unless explicitly asked." \
  --validation "Run the relevant tests if practical." \
  --dirty-worktree-warning \
  --output "$PROMPT_FILE"

LAUNCH_JSON=$(python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/start_pi_workspace.py \
  --cwd /path/to/repo \
  --label "Short task label" \
  --prompt-file "$PROMPT_FILE")

PANE_ID=$(printf '%s' "$LAUNCH_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["pane_id"])')
```

`start_pi_workspace.py` waits for Pi startup output and idle status before sending the prompt, then prints JSON with `workspace_id` and `pane_id`. Use `--ready-timeout-ms` or `--idle-timeout-ms` to tune those waits if startup is slow.

To send a prompt to an already-open pane, or to a pane you created with `herdr pane split`:

```bash
python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/send_prompt_to_pane.py \
  --pane "$PANE_ID" \
  --start-pi \
  --prompt-file "$PROMPT_FILE"
```

To monitor the child session:

```bash
python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/monitor_pane.py \
  --pane "$PANE_ID" \
  --wait-status done \
  --lines 100
```

## Fallback from tmux `agent-start` failure

If `agent-start` fails with `Failed to determine current tmux session`, do **not** create a duplicate issue or abandon delegation. Use Herdr:

```bash
# 1. Preserve the failed task as a handoff prompt.
PROMPT_FILE=$(mktemp -t pi-handoff.XXXXXX.md)
python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/write_handoff_prompt.py \
  --cwd "$PWD" \
  --goal "<same task you would have given agent-start>" \
  --context "tmux side-agent launch failed: Failed to determine current tmux session." \
  --guardrail "Inspect git status first and avoid unrelated dirty files." \
  --done "Report changed files, validation, blockers, and next steps." \
  --output "$PROMPT_FILE"

# 2. Launch the child in Herdr instead.
python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/start_pi_workspace.py \
  --cwd "$PWD" \
  --label "fallback subagent" \
  --prompt-file "$PROMPT_FILE"
```

If Herdr itself is not running, launch/attach it with `herdr` first, then rerun the helper. If the target repo should be isolated, create a git worktree manually before launch and use that path as `--cwd`.

## Manual launch recipe

If the scripts are unavailable, use raw Herdr commands:

```bash
CREATE_JSON=$(herdr workspace create \
  --cwd /path/to/repo \
  --label "Short task label" \
  --focus)

PANE_ID=$(printf '%s' "$CREATE_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')

herdr pane run "$PANE_ID" "pi"
herdr wait agent-status "$PANE_ID" --status idle --timeout 30000 || true
herdr pane send-text "$PANE_ID" "$(cat "$PROMPT_FILE")"
herdr pane send-keys "$PANE_ID" Enter
herdr pane get "$PANE_ID"
```

## Existing-pane / split-pane variant

Use this when you are already in a Herdr workspace and want a sibling pane instead of a new workspace:

```bash
SPLIT_JSON=$(herdr pane split --current --direction right --cwd /path/to/repo --focus)
PANE_ID=$(printf '%s' "$SPLIT_JSON" | python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/extract_ids.py pane)
python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/send_prompt_to_pane.py \
  --pane "$PANE_ID" \
  --start-pi \
  --prompt-file "$PROMPT_FILE"
```

Use `--no-focus` when the current pane should remain active.

## Monitor the child Pi

```bash
herdr pane get "$PANE_ID"
herdr pane read "$PANE_ID" --source recent --lines 80
herdr wait agent-status "$PANE_ID" --status done --timeout 120000
```

Agent statuses include `idle`, `working`, `blocked`, `done`, and `unknown`. If `done` never arrives, read recent output and decide whether to wait, steer the child, or close the pane.

## Smoke test

A minimal smoke test should prove that Herdr can launch Pi, receive a prompt, and produce visible output:

```bash
TMP_REPO=$(mktemp -d)
git -C "$TMP_REPO" init -q
PROMPT_FILE="$TMP_REPO/smoke-prompt.md"
cat > "$PROMPT_FILE" <<'PROMPT'
You are a Herdr/Pi delegation smoke test.
Do not edit files.
Reply with the marker made by joining HERDR_PI_SMOKE and RECEIVED with one underscore.
Then summarize the current directory and stop.
PROMPT

LAUNCH_JSON=$(python3 ~/.pi/agent/skills/herdr-pi-workspace/scripts/start_pi_workspace.py \
  --cwd "$TMP_REPO" \
  --label "pi smoke" \
  --prompt-file "$PROMPT_FILE")
PANE_ID=$(printf '%s' "$LAUNCH_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["pane_id"])')
herdr wait output "$PANE_ID" --match HERDR_PI_SMOKE_RECEIVED --source recent --lines 120 --timeout 180000
herdr pane read "$PANE_ID" --source recent --lines 120
```

Close the smoke-test workspace/pane after reviewing the output.

## Handoff prompt checklist

Include:

- Exact repo path and branch/worktree assumptions.
- Specific goal and non-goals.
- Links/paths to ADRs, docs, or files to read first.
- Existing decisions already made.
- Safety constraints and files not to touch.
- Validation commands to run if known.
- Expected final response format.

## Example: implementation spike

```text
You are working in `/Users/emiller/src/personal/finances`.

Goal: scaffold a Cloudflare Python Workflow compatibility spike for Beancount sync.

Read first:
- `docs/adr/2026-05-11-cloudflare-python-workflow-for-beancount-sync.md`

Guardrails:
- Keep Dagster/NUC as production.
- Dry-run only; do not mutate ledger data.
- Do not enable cron yet.
- Inspect `git status --short`; avoid unrelated dirty files.

When done:
- Summarize changed files.
- Explain what remains before production.
- Mention Cloudflare Python compatibility risks.
```
