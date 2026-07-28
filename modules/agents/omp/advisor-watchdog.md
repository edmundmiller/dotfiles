---
purpose: Explain OMP advisor runtime, WATCHDOG discovery, cost, and fallback behavior.
applies_to: Configuring OMP advisors or project-specific review guidance.
entrypoint: hosts/seqeratop/default.nix and config/omp/models.yml.
verification: Use /advisor status and force a provider failure to observe retry_fallback_applied.
update_when: OMP advisor discovery, retry, roster, or cost behavior changes.
---

# OMP advisor and WATCHDOG configuration

## Source of truth

OMP's upstream implementation and documentation are authoritative:

- `docs/advisor-watchdog.md`
- `packages/coding-agent/src/session/session-advisors.ts`
- `packages/coding-agent/src/session/turn-recovery.ts`

The public `/docs/subagents` page is a client-rendered overview. Use the files above when behavior is ambiguous.

## Runtime model

An advisor is a separate agent with its own model usage and append-only context. It receives each new primary transcript delta after a turn, can inspect the workspace with read-only tools by default, and returns at most one deduplicated advisory per update.

Every active roster entry is a separate advisor runtime. Two entries therefore create two independent review streams; their token and cost totals are visible with `/advisor status`. `advisor.subagents: true` also attaches advisors to eligible task/eval subagents.

Seqeratop intentionally uses one normal advisor stream:

- role: `advisor`
- primary: `openai-codex/gpt-5.6-sol:high`
- fallback: `vibeproxy/claude-opus-4-8:high`
- roster name: `Sol`

The roster omits `model`, so it resolves through `modelRoles.advisor`. This lets `retry.fallbackChains.advisor` own the fallback without changing other roles that happen to use Sol.

## Retry behavior

Current OMP source applies provider-failure fallback chains to advisor runtimes when `retry.enabled` and `retry.modelFallback` are enabled. Advisor recovery resolves a chain key in this order:

1. Exact model selector.
2. Provider wildcard.
3. Matching model role.
4. `default`.

Prefer the `advisor` role chain for an advisor-only fallback. An exact `openai-codex/gpt-5.6-sol:high` chain would also affect any primary role using that selector.

VibeProxy custom providers have no model auto-discovery. Every fallback id must also appear in `config/omp/models.yml`; keep the served Opus 4.8 entry while Opus 5 availability is pending.

## WATCHDOG files

- `WATCHDOG.yml` declares advisor roster entries, models, tools, and specialization instructions.
- `WATCHDOG.md` supplies advisor-only review priorities.

OMP loads the user-level files plus every project file found from the working directory to the repository root. Files are additive, not nearest-file-only:

- Top-level YAML instructions concatenate.
- Advisors with different names all run.
- A more-specific file replaces only an advisor with the same slugified name.
- Multiple Markdown guidance files concatenate, with narrower project guidance later in the prompt.

A project that needs different review priorities should add `.omp/WATCHDOG.md`. To replace the global `Sol` advisor rather than add another stream, use the same `name: Sol` roster entry in its project `WATCHDOG.yml`.

## Operating checks

- `/advisor status` — active model, context, tokens, and cost.
- `/advisor dump raw` — system prompt, transcript, thinking, and calls.
- `/advisor off` — disable advisor runtime for the current session only.
- `omp stats` — attributes persisted advisor usage to the owning session/project.

Advisor failures do not permanently stall the primary. Recovery first tries usable credentials, then the configured fallback chain. After three consecutive failures, OMP warns, drops the advisor backlog, and lets the primary continue.
