---
name: deslop
description: >
  Run a multi-agent review-readiness pass on a nearly finished change before
  commit; fan out parallel review agents across rule conformance, type safety,
  and overengineering, then synthesize and apply the worthwhile fixes.
---

# Deslop

Run this only after the change is functionally correct and before `commit`.
PR text should describe already-deslopped code.

## Goals

- Keep the smallest clear diff that still solves the task.
- Run focused reviews in parallel instead of one subjective final pass.
- Preserve behavior while improving clarity, type safety, and rule alignment.

## Required review vectors (exactly 3 agents, in parallel)

All 3 agents get the same context bundle, but each gets one vector:

1. **Rules and docs conformance**
   - Check `AGENTS.md`, nested `AGENTS.md`, design docs, and core beliefs.
   - Flag drift from documented patterns or ownership boundaries.
2. **Type safety and source of truth**
   - Preserve canonical types and inference flow.
   - Flag casts, duplicated/redefined types, or unnecessary widening.
   - Prefer compile-time guarantees inside typed internal code.
   - Validate only at untrusted boundaries; do not re-validate trusted internal values.
3. **Overengineering and simplification**
   - Remove unnecessary code, wrappers, abstractions, factories, or indirection.
   - Prefer direct, local solutions when equivalent.

## Required context bundle

Read and pass these paths:

- repo root `AGENTS.md`
- nested `AGENTS.md` for changed areas
- `docs/index.md`
- `docs/PLANS.md`
- `docs/design-docs/index.md`
- `docs/design-docs/core-beliefs.md`
- directly relevant design docs
- active exec plan for this work (if any)
- changed files plus nearby context

If working on an ExecPlan:

- inspect `docs/exec-plans/active/`
- if one clearly matches, tell reviewers to study it carefully before reviewing

## Delegation protocol

1. Read the full context bundle yourself first.
2. Launch all 3 required review agents immediately (in parallel).
   - Do **not** wait for local lint/slop checks.
3. Give each agent:
   - same context bundle
   - one assigned review vector
   - instruction to return findings first, ordered by severity, with file refs
4. While agents run, start with:
   - `pnpm -w lint:slop:delta`
5. After all responses arrive, synthesize under these exact headings:
   - `How did we do?`
   - `Feedback to keep`
   - `Feedback to ignore`
   - `Plan of attack`
6. Use balanced synthesis over any single reviewer’s extreme take.

## Auto-apply feedback (unattended flows)

Apply clear, in-scope fixes before commit, prioritizing:

- type drift, casts, duplicate type definitions
- documented boundary/design-belief violations
- dead helpers/code/debug leftovers/placeholders
- removable local indirection

Skip speculative, conflicting, or scope-expanding suggestions; note briefly in synthesis/workpad.

## Execution steps

1. Gather context bundle.
2. Launch 3 required review agents in parallel.
3. Run `pnpm -w lint:slop:delta` and narrow local checks while they run.
4. Wait for responses and synthesize.
5. Apply worthwhile in-scope feedback.
6. Re-run the narrowest affected validation.
7. Update workpad/commit/PR text to describe final post-deslop state.

## Stop rules

- No refactors unrelated to the ticket.
- No churn outside changed area for style only.
- Leave subjective/unclear “improvements” alone.
- Do not blindly apply every suggestion.
