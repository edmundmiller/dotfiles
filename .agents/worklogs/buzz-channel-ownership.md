# Worklog: buzz-channel-ownership

Status: active

## Objective

Enforce one documented Buzz channel ownership matrix: ambient intake only for a single dedicated owner, mention-gating for shared/report channels, Betty removed from fitness and Monica booking automation, and Flue Workouts established as the personal fitness owner. Stop after source, tests, deployments, live state, and remote default branches agree.

## Decisions

- Preserve the owner/Moni author gates independently from channel subscription mode.
- Use `buzz-acp --subscribe=config` rules for every Hermes profile. Include forum root/reply kinds explicitly; use `require_mention=false` only for Betty in `meal-planning`.
- Keep shared project, general, finance, and report channels mention-gated.
- Remove Betty from `fitness`, retire her Monica Life Time cron and active booking/planning capability, and leave personal fitness to the existing Flue Workouts workflow outside Hermes/Buzz.
- Keep the legacy `fitness` channel human-only rather than introducing a new cross-project Cloudflare bridge or reusing another agent identity.
- Make `agents-workspace/deployments/nuc/buzz-bindings.nix` the executable matrix and mirror it as a table in ADR-0011.

## Evidence

- Live NUC `buzz-acp` 0.4.26 supports `subscribe=config` and `BUZZ_ACP_CONFIG`.
- Pinned upstream source resolves unmatched config channels to no subscription and supports per-rule `require_mention`.
- Personal Workouts already runs as Flue `plan-today`/`plan-week`; it has no Buzz intake or identity.
- Mill Docs has a separate Buzz→Flue worker and identity; reusing it would violate ownership and identity boundaries.

## Reviews

- Plan review unavailable: default reviewer returned `RUNTIME: Authentication required`; the configured OpenCode fallback lacks its postinstall runtime. Manual scope review kept the change to canonical bindings, NUC rendering, retirement wiring, tests, and docs.

## Feedback

- Pending.

## Remaining work

- Land dotfiles, deploy NUC, verify live services and Betty cron/skills, run landing review/audit, and clean task worktrees.

## Commits

- agents-workspace `1f6ecd6`: canonical channel matrix and Betty fitness/Life Time retirement; remote `main` verified.
