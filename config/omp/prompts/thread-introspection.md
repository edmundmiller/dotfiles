# OMP Thread Introspection

Analyze OMP/Codex sessions for `{{DATE}}` and improve the agent system only where the evidence supports it.

## Inputs

The script appends a JSON session manifest after this prompt. Each item has:

- `path`: OMP session JSONL path
- `bytes`: file size
- `modified`: local modification timestamp

Read only the sessions needed to establish patterns. Filter at the source: prefer sampling thread starts, user prompts, assistant failures, repeated tool errors, and final outcomes before loading large files.

## Goals

1. Extract durable user preferences and project decisions.
2. Find where OMP/Codex struggled, looped, repeated work, ignored available tools, overbuilt, under-verified, or violated repo conventions.
3. Update skills, rules, or prompts only when a change would prevent recurrence.
4. Keep changes small, concrete, and tied to observed failures.
5. Prefer existing files over new files.

## Edit policy

Allowed targets:

- `skills/catalog/*/SKILL.md`
- `skills/catalog/*/references/*`
- `config/agents/rules/*.md`
- `config/omp/prompts/*.md`
- `.agents/skills/*/SKILL.md`
- `.agents/skills/*/references/*`

Do not edit runtime symlinks under `~/.omp`, `~/.pi`, or `~/.claude`.
Do not edit secrets, lock files, generated files, or unrelated source.
Do not add broad generic advice. Add rules only when they would have changed behavior in an observed thread.
Do not create a new skill unless no existing skill/rule can naturally hold the lesson.

## Evidence threshold

Apply an update only when one of these is true:

- at least two sessions show the same problem or preference
- one session shows a severe failure with clear prevention value
- the user explicitly stated a durable preference or instruction

If evidence is weak, report it without editing.

## Output

Return a concise report:

- Sessions reviewed
- Preferences or decisions retained
- Recurring failures found
- Files changed
- Checks or limitations
- Follow-up work, if any
