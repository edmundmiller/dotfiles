---
name: deslop
description: >
  Run a multi-agent review-readiness pass on a nearly finished change before
  commit; fan out parallel review agents across rule conformance, type safety,
  and overengineering, then synthesize and apply the worthwhile fixes.
---

# Deslop

Use this skill after the change is functionally correct and before `commit`.
The PR should be describing already-deslopped code, not code that still needs cleanup.

## Goals

- Leave the smallest clear diff that still solves the issue.
- Run multiple focused review passes in parallel instead of relying on one final subjective read.
- Preserve behavior while improving readability, type safety, and alignment with repo rules.

## Required review vectors

Launch exactly these 3 parallel subagents as soon as the context bundle is ready.
Give all of them the same context bundle, but assign each a different review vector:

1. Rules and documentation conformance
   - Are we following `AGENTS.md`, nested `AGENTS.md`, design docs, and core beliefs?
   - Did we drift from documented repo patterns or ownership boundaries?
2. Type safety and source of truth
   - Are we preserving canonical types?
   - Did we cast, redefine existing types, widen things unnecessarily, or break inference flow?
   - Could a mistake slip to deploy time instead of build time?
   - Prefer compile-time guarantees over runtime defensive programming inside typed repo-owned code. Validate or parse only at untrusted boundaries. Once data has crossed a validator-owned boundary or is carried by an inferred repo-owned type, trust it downstream and do not re-parse it.
   - Use boundary validation only. Do not add defense-in-depth revalidation inside internal TypeScript helpers unless the input is truly untrusted or the operation is irreversible.
3. Overengineering and simplification
   - Did we write more code than needed?
   - Did we create helpers, abstractions, factories, wrappers, or indirection without enough payoff?
   - Could the same result be expressed more directly?

## Required context bundle

Before delegating, collect and pass the exact paths the reviewers need:

- repo root `AGENTS.md`
- nested `AGENTS.md` files for the changed areas
- `docs/index.md`
- `docs/PLANS.md`
- `docs/design-docs/index.md`
- `docs/design-docs/core-beliefs.md`
- any design doc directly relevant to the changed area
- the relevant active exec plan when one exists for the current work
- the changed files and enough nearby context to review them properly

If you're working on an ExecPlan, also include:

- inspect `docs/exec-plans/active/`
- if one clearly matches the current task, inform the sub agent to study it extensively before starting their focused review as often it contains relevant context, constraints, and acceptance criteria that are not captured in the ticket or design docs.

## Delegation protocol

1. Read the context bundle yourself first so the delegation is precise.
2. Spawn the 3 required parallel subagents immediately.
   - Do not wait to run local linting or slop checks before delegating.
   - The point is to let the reviewers work in parallel while you do local verification.
3. Give each agent:
   - the same context bundle, plus any critical user context that is not captured in the files
   - one assigned review vector
   - clear instructions to return findings first, ordered by severity, with file references
4. Wait for all review agents to return.
   - While they run, start with `pnpm -w lint:slop:delta` to prime yourself on the highest positive deltas, newly introduced hotspots, and the largest improvements.
5. Read all responses and synthesize them into one balanced report with these headings:
   - `How did we do?`
   - `Feedback to keep`
   - `Feedback to ignore`
   - `Plan of attack`
6. Prefer the balanced synthesis over any one subagent's extreme take.

## What to fix automatically

If you are in an unattended implementation flow, apply the worthwhile feedback immediately before commit. Prioritize:

- type drift, casting, or duplicated type definitions
- violations of documented repo boundaries or design beliefs
- dead helpers, dead code, debug leftovers, placeholder text
- unnecessary wrappers or indirection that can be removed locally without widening scope

If feedback is speculative, conflicts across reviewers, or would widen scope materially, leave it out and mention it briefly in the synthesis/workpad.

## Steps

1. Gather the context bundle.
2. Launch the 3 required review agents in parallel.
3. While they run, use `pnpm -w lint:slop:delta` to identify the biggest regressions and improvements, then run any other narrow local checks you need.
4. Wait for their responses and synthesize them.
5. Apply the worthwhile feedback that is clearly in scope.
6. Rerun the narrowest affected validation immediately.
7. Update workpad, commit text, and PR-facing text so they describe the final post-deslop state rather than the earlier draft state.

## Stop rules

- Do not turn this into a refactor unrelated to the ticket.
- Do not churn stable code outside the changed area just to make it prettier.
- If a cleanup is subjective and not clearly better, leave it alone.
- Do not blindly apply every subagent suggestion.
