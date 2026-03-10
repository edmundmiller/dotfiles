---
description: Launch Codex CLI in overlay to review implemented code changes (optionally against a plan)
---

Read the Codex prompting guide at https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide.md using fetch_content or web_search. Then determine the review scope:

- If `$1` looks like a file path (contains `/` or ends in `.md`): read it as the plan/spec these changes were based on. The diff scope is uncommitted changes vs HEAD, or if clean, the current branch vs main.
- Otherwise: no plan file. Diff scope is the same. Treat all of `$@` as additional review context or focus areas.

Run semantic analysis first: `sem diff` (prefer `sem diff --format json`, fallback `git diff`) to enumerate changed files/entities. For high-risk entities, also gather `sem graph --entity <symbol>` and `sem impact <symbol>` context. Use this to calibrate review depth.

Based on the prompting guide's best practices, the diff scope, and the optional plan, generate a comprehensive meta prompt tailored for Codex CLI. The meta prompt should instruct Codex to:

1. Start from `sem diff` output to identify changed files and changed entities (fallback `git diff` only if needed). Read every changed file in full — not just hunks.
2. For high-risk changed entities, run `sem graph --entity <symbol>` to map direct dependencies/dependents. Read the most relevant upstream/downstream files to validate integration points.
3. If a plan/spec was provided, read it and verify implementation completeness — every requirement addressed, no skipped steps, no out-of-scope invention, no partial stubs.
4. Review changed code for: logic bugs, race conditions, resource leaks, null/undefined hazards, off-by-one errors, weak error handling, type mismatches, dead code, unused symbols, unnecessary complexity, and convention drift.
5. For high-risk entities, run `sem impact <symbol>` and trace end-to-end paths (data flow, state transitions, error propagation, cleanup ordering). Use `sem blame <file>` when regression context or ownership history helps disambiguate intent.
6. Check tests/docs/changelog coverage; fix every issue directly in code; then summarize findings, fixes, and any remaining human-judgment calls.

The meta prompt should follow the Codex guide's structure: clear system context, explicit scope and verbosity constraints, step-by-step instructions, and expected output format. Emphasize thoroughness — read the actual code deeply before making judgments, question every assumption, and never rubber-stamp.

Then launch Codex CLI in the interactive shell overlay with that meta prompt using these flags: `-m gpt-5.3-codex -c model_reasoning_effort="high" -a never`. Do NOT pass sandbox flags in interactive_shell. End your turn immediately after launching -- do not poll the session. The user will manage the overlay directly.

$@
