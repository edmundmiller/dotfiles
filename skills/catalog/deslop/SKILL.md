---
name: deslop
compatibility: portable
description: Reviews and simplifies changed code without changing behavior. Use for simplify, code-simplifier, cleanup, readability, reuse, efficiency, or final review-readiness requests. Not for prose editing or product scope cuts.
---

# Deslop

Review a functionally correct change before an authorized commit or handoff.
This skill does not authorize committing or publishing.

`unslop` owns prose and UI-voice policy; this skill owns code review-readiness.

This entrypoint also covers the former `simplify` and `code-simplifier` skills.
Read [reuse, quality, and efficiency](references/simplify.md) for a changed-code
review, or [readability refinement](references/code-simplifier.md) for a focused
cleanup. Preserve outputs, side effects, and error behavior. Default to the
changed code, not a repository-wide refactor. Prefer explicit control flow over
clever compression and retain useful abstractions.

## Review

Read the diff and nearby code, applicable `AGENTS.md`, and relevant design docs
or active plan. Use the task's acceptance criteria; do not invent missing project
conventions or expand scope. Cover these checks:

1. **Rules and docs:** check ownership, documented patterns, and design constraints.
2. **Type safety and source of truth:** preserve canonical types and inference;
   flag casts, duplicate types, or unnecessary widening. Prefer compile-time
   guarantees internally and validate untrusted inputs at boundaries.
3. **Simplicity:** remove dead helpers, debug leftovers, and unnecessary wrappers
   or indirection. Preserve behavior and useful abstractions.
4. **Reuse and efficiency:** check existing helpers before adding new ones;
   inspect duplicate work, N+1 reads, hot-path blocking, unbounded state, resource
   cleanup, and overly broad reads. Do not introduce a new abstraction merely to
   unify similar-looking code. Use `auditing-performance` for a measured
   performance investigation rather than treating this review as a benchmark.

Perform these checks locally. If delegation is authorized and useful, give each
reviewer the same context and one check; request findings ordered by severity
with file references. Assess their evidence rather than accepting every suggestion.

## Apply and verify

Apply clear, in-scope fixes. Leave speculative or subjective changes alone;
explain unresolved consequential findings. Do not refactor unrelated code or
create style-only churn.

Run the repository's narrow checks, including `pnpm -w lint:slop:delta` only if
that script exists. Rerun affected validation after edits. Report findings,
fixes, evidence, and remaining limitations concisely; no fixed headings or extra
workpad are required. Commit or PR text, when requested, describes the final state.

The reference workflows do not expand these scope or authority boundaries.
See [simplify provenance](references/simplify-source.md) when refreshing its guide.
