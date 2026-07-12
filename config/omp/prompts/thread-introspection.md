# Agent Thread Introspection

Analyze OMP, Codex, Claude Code, Pi, OpenCode, Amp, Droid, and other agent sessions for `{{DATE}}`; improve the shared agent system only where the evidence supports it.

## Inputs

The script appends a JSON session manifest after this prompt. Each item has:

- `client`: source agent/runtime, such as `omp`, `codex`, `claude`, `pi`, `opencode`, `amp`, or `droid`
- `format`: underlying file format, such as `jsonl`, `json`, or `sqlite`
- `path`: session/transcript path
- `bytes`: file size
- `modified`: local modification timestamp

Read only the sessions needed to establish patterns. Filter at the source: prefer sampling thread starts, user prompts, assistant failures, repeated tool errors, and final outcomes before loading large files.

## Parallel analysis

- With zero or one manifest entry, inspect it directly and do not spawn a worker.
- With two or more entries, group entries by `client`, then greedily balance each client group by `bytes` into no more than eight disjoint shards. Launch every shard in one Task batch with read-only `scout` agents.
- Give each worker only its shard’s manifest entries. Require the worker’s `summary` field itself to contain these headings: `Sessions inspected`, `Repeated failures or preferences`, `Evidence locations`, and `Smallest durable prevention surface`. Under `Sessions inspected`, list every assigned path verbatim exactly once; do not rely on a separate files field. Workers never edit files.
- Before synthesis, require one successful result per shard and exact set equality between manifest paths and the union of paths under `Sessions inspected`. A path must appear in exactly one shard.
- Retry a failed shard once. If it still fails, inspect that shard directly in the main process. If any manifest path remains missing or duplicated, make no edit or commit; report the failed shard and path set and leave related work open.
- Only the main process writes. Apply a durable change only after complete path coverage and when the existing evidence threshold below is met. Weak findings are report-only.

## Goals

1. Extract durable user preferences and project decisions.
2. Find where agents struggled, looped, repeated work, ignored available tools, overbuilt, under-verified, or violated repo conventions.
3. Update skills, rules, or prompts only when a change would prevent recurrence.
4. Keep changes small, concrete, and tied to observed failures.
5. Prefer existing files over new files.

## Memory and skill boundary

Keep memories and skills separate.

- Memories store user-specific facts, preferences, names, paths, hosts, secrets, accounts, and project history.
- Skills store reusable procedures that should remain useful without private context.
- Do not copy session text, memory extracts, personal identifiers, machine names, account names, secret paths, home paths, private URLs, or one-off user preferences into skills.
- Convert a repeated failure into a generic procedure. Example: write "verify the host before host-specific commands", not "on HOSTNAME...".
- If a durable preference belongs in memory, report it; do not encode it in a skill unless it is a general workflow rule.

Before and after editing any skill, scan the changed skill text for personal data. Report only counts, file paths, rule names, and line numbers; do not quote matched values.

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
