# Worklog: hermes-cron-single-owner

Status: active

## Objective

Make the NUC's Amos, Betty, and Scintillate cron execution single-owner: retain the existing 60-second host systemd timers, explicitly disable each gateway's in-process ticker, publish an external-executor marker for every timer-owned profile, and preserve direct `hermes cron tick` behavior.

Stop only after focused Nix checks pass; the exact committed and pushed dotfiles/agents-workspace revisions are deployed; all three timer/service pairs and gateway settings are read back; and fresh ledger rows prove distinct successful host-owned executions with no new gateway-owned or `unknown` attempts.

## Decisions

- Preserve the deliberate host timer executor because it owns the required host environment, working directory, and packages.
- Add a gateway-only Hermes setting with a backward-compatible default; do not change Desktop cron or the direct CLI tick path.
- Treat malformed executor-ownership configuration as an error instead of silently creating zero or two executors.
- Keep reusable runtime behavior in agents-workspace and host ownership, timers, markers, and deployment checks in dotfiles.

## Evidence

- Live ledger rows owned by container PID 1 use process-start fingerprint `94960715`; host `/proc/1` uses fingerprint `27`.
- Each subsequent host tick runs recovery in the host PID namespace and marks the live gateway attempt `unknown`.
- Host timer services run synchronous `hermes cron tick` with `TimeoutStartUSec=infinity`; early exit and systemd timeout were falsified.
- Existing `jobs.json last_status=ok` is separate from the authoritative execution ledger.

## Reviews

- Plan/cause audit: exact Hermes v2026.8.19 source, live systemd units, Podman process identity, and SQLite execution rows were inspected read-only.
- Landing review: pending implementation and fresh exact-head review.

## Feedback

- The prior one-executor tracker contract had no deployed assertion, allowing both trigger lanes to coexist.

## Remaining work

- Land the agents-workspace gateway-only ticker control and tests.
- Apply the patch in the dotfiles overlay; configure all three profiles; add executor markers and Nix assertions.
- Build, review, push, deploy, and independently read back runtime and ledger state.

## Commits

None.
