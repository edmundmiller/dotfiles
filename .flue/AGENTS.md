# Flue observability

This is the Node Flue application for bounded Renovate patch repair. See the
[runbook](../docs/agents/flue-observability.md) for commands and coverage limits.
These conventions adapt `evlog agents --no-skills` to Flue; maintain them here
rather than replacing them with generic HTTP guidance.

- Install instrumentation once in `app.ts`, never inside an agent initializer.
- Emit one terminal wide event per model call, tool, task, and operation. Start
  and shutdown records detect interrupted or incomplete exports.
- Sum only `turn` usage, including compaction turns. Operation and compaction
  summaries overlap those tokens. Missing usage is unknown, never measured zero.
- Preserve Flue's IDs and measured durations. Costs are estimates, not invoices.
- Keep the explicit field allowlist in `../packages/flue-evlog/src/index.ts`. Never record prompts,
  responses, reasoning, tool arguments/results, raw errors, or environment dumps.
- Use `c.get("log")` and grouped context for HTTP handlers. Use structured safe
  errors at that boundary; local CLI validation errors may use ordinary errors.
- Do not sample accounting records. Await persistence on shutdown and fail
  accounting checks on missing, malformed, or unmatched lifecycle records.
- Use the installed CLI through `npm run observe -- map`, `doctor`, or `summary`.
  The map scores Hono transport only. `hey check .flue packages/flue-evlog` also
  exercises real Flue execution with a local fixture provider and no paid model calls.
- Keep `.flue/observability.ts` as application policy. The reusable adapter owns
  events and accounting, while this app owns storage and CI metadata. Build the
  package before installing this app; reinstall after changing the package.
- Logging guidance lives in `../skills/catalog/review-logging-patterns`,
  `build-audit-logs`, and `analyze-logs`. Do not run an ad hoc skills installer.
- Repair only the allowed patch stack. Telemetry does not authorize more tools,
  broader file writes, model-driven publication, deployments, or credential access.
