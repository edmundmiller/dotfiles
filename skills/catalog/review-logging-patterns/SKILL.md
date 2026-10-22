---
name: review-logging-patterns
description: Reviews TypeScript and JavaScript logging patterns and guides evlog adoption. Use when replacing console logs, improving structured errors or request context, configuring drains, sampling, redaction or AI logging, or checking evlog entry-point coverage.
license: MIT
metadata:
  author: HugoRCD
  source: https://github.com/evloghq/evlog/tree/c5dd007b9552048068f3dfc801a7625144554992/skills/review-logging-patterns
  pin: c5dd007b9552048068f3dfc801a7625144554992
---

# Review logging patterns

Review logging in the requested application code. Prefer one wide event per
operation, grouped business context, structured errors, and explicit safe fields.

## Workflow

1. Identify the framework and the user's requested scope. Read the relevant
   section of the [upstream logging guide](references/logging-guide.md) for setup,
   CLI usage, configuration, adapters, enrichers, redaction, or AI SDK integration.
2. Ask before installing packages or fetching an on-demand CLI. Prefer the
   project's installed, lockfile-pinned executable. Preview setup changes before
   applying them. Do not run `evlog agents` or a skills installer just to review
   logging, because they write instructions or install skills.
3. On supported frameworks, optionally run `evlog map --no-write`, fix the
   requested findings, and rerun the same command. Otherwise use the manual
   checklist. A static score checks instrumentation shape, not runtime behavior.
4. Keep edits within the requested scope. Do not add CI gates, change project
   instructions, enable remote drains, or deploy without authorization.
5. Run the application's focused checks and report findings and any unverified
   runtime behavior. Never copy credentials or raw sensitive logs into reports.

## References

Load only the reference needed for the current task.

- [Full upstream guide](references/logging-guide.md) covers framework setup,
  CLI setup and coverage, configuration, adapters, redaction, and AI logging.
- [Wide events](references/wide-events.md) covers event shape and context.
- [Structured errors](references/structured-errors.md) covers error fields and clients.
- [Code review](references/code-review.md) supplies the review checklist.
- [Drain pipeline](references/drain-pipeline.md) covers batching, retry, and shutdown.
- [Build audit logs](../build-audit-logs/SKILL.md) covers sensitive-action audit trails.
- [Source and review notes](SOURCE.md) records the vendored revision and local changes.
