---
name: herdr-voice-dispatcher
description: Dispatches spoken or written prompts to live Herdr agents and reports their status or results. Use when the user says to list, check, ask, tell, prompt, steer, or wait for an OMP, Codex, or other agent running in Herdr.
---

# Herdr voice dispatcher

Translate conversational requests into bounded Herdr CLI actions. This skill is
an external controller for Codex Voice or chat, so it intentionally works
without `HERDR_ENV=1`.

## Connect

1. Run the concise inventory without native session references:

   ```bash
   python3 ~/.agents/skills/herdr-voice-dispatcher/scripts/list_agents.py
   ```

2. If Herdr is unavailable, report the exact error.
   - For `Operation not permitted`, ask the user to run the Codex task with
     Full Access; a skill cannot bypass the sandbox.
3. Do not dump raw `herdr agent list` output. It includes noisy native session
   references.

## Resolve the target

- Use an exact live agent name or pane ID.
- If the user names a project, title, or directory, filter the inventory:

  ```bash
  python3 ~/.agents/skills/herdr-voice-dispatcher/scripts/list_agents.py --query dotfiles
  ```

- Treat labels such as `omp` or `codex` as agent kinds, not unique targets,
  when several matches exist.
- If more than one candidate remains, ask one concise clarification. Never
  guess a pane.

## Act

**List or check status:** use the inventory helper. Use `herdr agent get
"$target"` only when more detail about one resolved agent is necessary.

**Dispatch work:** preserve the user's requested outcome and constraints, then
submit without waiting:

```bash
herdr agent prompt "$target" "$prompt"
```

Report only that Herdr accepted the prompt. If the target was already
`working`, explain that Herdr lifecycle state does not correlate completion to
an individual queued turn.

**Read a result:** check status, then read bounded output:

```bash
herdr agent read "$target" --source recent-unwrapped --lines 80
```

If recent output is incomplete because the agent uses an alternate screen, use
`--source visible`. Do not claim success from `unknown` state or truncated
output.

**Wait when explicitly requested:** keep Voice responsive with a bounded wait:

```bash
herdr agent wait "$target" \
  --until idle --until done --until blocked \
  --timeout 60000
```

If the agent becomes `blocked`, read and relay its question. Do not answer it
for the user.

## Guardrails

1. Prompt only the target and intent the user authorized.
2. Never start, stop, focus, interrupt, send keys, or answer an approval unless
   the user explicitly requests that exact action.
3. Treat dispatch as an external state change; a zero exit status proves
   submission, not task completion.
4. Do not expose agent session paths or unrelated terminal content.
5. Never wait indefinitely. Return control after 60 seconds and offer a fresh
   status check.

## Spoken examples

- “Which Herdr agents need attention?” → list and summarize `blocked`,
  `working`, and `done`.
- “Tell the dotfiles reviewer to inspect the current diff without editing.” →
  resolve one target, dispatch once, and return immediately.
- “What did the reviewer say?” → check its state, then read bounded output.
- “The reviewer is blocked—what does it need?” → read and relay the question
  without answering it.
