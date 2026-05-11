---
name: herdr-pi-workspace
description: "Create a new Herdr workspace/pane for a repo and kick off a Pi session with a structured handoff prompt. Use when the user asks to start a new Herdr workspace, space, pane, or Pi session for delegated work."
---

# Herdr Pi Workspace Handoff

Use this skill to spin up a focused Herdr workspace in another repository and start Pi with a high-quality handoff prompt.

## When to use

- The user asks to "start a new Herdr workspace/space" for a task.
- The user asks to "kick off a Pi session" in a repo.
- You want a sibling Pi agent to implement or investigate work while preserving your current context.

## Principles

- Create a concise but complete handoff prompt before launching Pi.
- Include repo path, goal, known context, constraints, guardrails, and expected final summary.
- Tell the child Pi to inspect `git status --short` before editing.
- Warn about unrelated dirty files when you know they exist.
- Prefer a two-step Pi launch for long prompts: start `pi`, then send the prompt into the TUI.
- Avoid putting secrets or tokens in the prompt.

## Scripts

The skill includes small dependency-free Python helpers in `scripts/`:

- `write_handoff_prompt.py` — generate a structured handoff prompt file from arguments.
- `start_pi_workspace.py` — create a Herdr workspace, launch Pi, and submit a prompt file.
- `send_prompt_to_pane.py` — submit a prompt file to an existing Herdr pane, optionally starting Pi first.
- `monitor_pane.py` — inspect a pane, optionally wait for an agent status, and print recent output.
- `extract_ids.py` — parse Herdr JSON from stdin and print workspace/tab/pane ids for shell pipelines.

## Preferred scripts

Use the included helpers when available. They handle workspace creation, pane-id parsing, Pi startup, and prompt submission.

```bash
PROMPT_FILE=/tmp/my-pi-handoff.md
python3 ~/.agents/skills/herdr-pi-workspace/scripts/write_handoff_prompt.py \
  --cwd /path/to/repo \
  --goal "Implement/investigate ..." \
  --context "Known fact ..." \
  --read-first "docs/adr/example.md" \
  --guardrail "Keep changes small and reviewable." \
  --validation "Run the relevant tests if practical." \
  --output "$PROMPT_FILE"

python3 ~/.agents/skills/herdr-pi-workspace/scripts/start_pi_workspace.py \
  --cwd /path/to/repo \
  --label "Short task label" \
  --prompt-file "$PROMPT_FILE"
```

`start_pi_workspace.py` prints JSON with `workspace_id` and `pane_id`.

To send a prompt to an already-open Pi pane:

```bash
python3 ~/.agents/skills/herdr-pi-workspace/scripts/send_prompt_to_pane.py \
  --pane "$PANE_ID" \
  --prompt-file "$PROMPT_FILE"
```

To monitor the child session:

```bash
python3 ~/.agents/skills/herdr-pi-workspace/scripts/monitor_pane.py \
  --pane "$PANE_ID" \
  --wait-status done \
  --lines 100
```

## Manual launch recipe

If the script is unavailable, use the raw Herdr commands:

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

Why two steps? `pi "$(cat prompt.md)"` may open Pi but not reliably submit a long startup prompt in every TUI/context. Starting Pi first and then using `send-text` + `Enter` is more reliable.

## Non-focusing variant

Use `--no-focus` if the current workspace should stay active:

```bash
CREATE_JSON=$(herdr workspace create \
  --cwd /path/to/repo \
  --label "Short task label" \
  --no-focus)
```

Then parse `PANE_ID` and launch Pi as above.

## Monitor the child Pi

```bash
herdr pane get "$PANE_ID"
herdr pane read "$PANE_ID" --source recent --lines 80
herdr wait agent-status "$PANE_ID" --status done --timeout 120000
```

Agent statuses include `idle`, `working`, `blocked`, `done`, and `unknown`.

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
