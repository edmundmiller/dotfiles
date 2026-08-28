# Worklog: buzz-hermes-production-deploy

Status: source-verified

## Objective

Deploy the published agents-workspace Buzz/Hermes stack through the canonical
dotfiles NUC package path, with exactly one cron owner per external-timer
profile, complete provenance, healthy profile runtimes, and a live Buzz demo.
Stop only when the source and deployment revisions are published and read back,
the running containers use the intended package, and the demo has authoritative
event, thread, and model evidence, or when a separate human-consent gate is the
only remaining blocker.

## Decisions

- Use a clean worktree from current `origin/main`; preserve the dirty canonical
  checkout untouched.
- Consume agents-workspace `main` containing PR #5 and preserve the canonical
  Buzz01-11, cron ownership, Buzz12 order.
- Keep the dashboard patch outside the Buzz composition manifest while applying
  it to the fleet package.
- Select systemd as the sole cron owner for Amos Burton, Betty, and Scintillate;
  pair `cron.gateway_ticker = false` with executor markers and active timers.
- Treat the user's request for a deployed demo as publication, deployment, and
  harmless live-Buzz authority. Monica contact, shared identity/channel changes,
  and household actions with real-world impact remain separately consent-gated.

## Evidence

- Agents-workspace PR #5 merged to `main` at `92186274d960773758203d6268e1a635b3a4f401`.
- Pre-change NUC generation 1422 reports `dotfiles=d20d1e8...;agents-workspace=7c427f1...`.
- Six gateways and the dashboard are active with zero restarts and no active
  agents; live package still lacks the final cron and dashboard behavior.
- Amos and Scintillate execution history reproduces the container/host PID
  namespace recovery defect; Amos and Betty executor markers are absent.
- The inherited 14-commit cron candidate keeps the timer cadence, writes all
  three markers atomically, rejects path aliases, and fail-closes deployment
  readback.
- `python3 tests/test_hermes_cron_executors.py`: 18 tests passed.
- Darwin source checks passed for canonical patch composition, final-stack
  behavior, cron ownership, dashboard liveness, and the dotfiles executor
  source contract.
- The production overlay now consumes `buzz-stack-order.txt`, keeps auxiliary
  Hermes behavior after Buzz12, applies dashboard liveness separately, and runs
  the final thread, cron, and dashboard tests during package install checks.
- The agents-workspace flake URL and lock both resolve to published main
  `92186274d960773758203d6268e1a635b3a4f401`.
- The exact Linux package and NUC system build succeeded from a clean,
  revision-stamped remote snapshot.
- Nine x86_64 checks passed together: canonical patch composition, bounded
  final behavior, single cron ownership, dashboard liveness, package layout,
  dashboard and six-gateway package wiring, cron host wiring, Buzz community
  runtime, and deployment provenance.
- Target evaluation reports
  `dotfiles=e1d0d462cdbf4e2690101be0f60a327a6fcabd94;agents-workspace=92186274d960773758203d6268e1a635b3a4f401`
  for the last source-identical verification snapshot.
- A later unattended upgrade activated generation 1427 from stale dotfiles
  commit `baf5a44155b16ee6e0144a0ddbda2fc920596876`; live
  `configurationRevision` regressed to that bare SHA instead of the required
  two-source stamp. The journal records a GitHub API rate-limit failure, Nix's
  cached-source fallback, and a failed switch result.
- The NUC wrapper now resolves dotfiles `origin/main` over Git transport,
  validates an exact lowercase commit SHA, and rewrites a mutating remote flake
  to that immutable revision before `nixos-rebuild` starts. Its packaged check
  passes 11 tests, including both flake argument forms and fail-closed invalid
  revision handling.

## Reviews

- Plan gate: the user explicitly authorized full publication, deployment, and a
  demo. Independent read-only source, dotfiles, live-fleet, acceptance, and
  dashboard audits identified the exact implementation and verification seams.
- Semantic review of the deployment delta found only the input pin, canonical
  patch composition, package assertions, and focused tests.

## Feedback

- Direct `nix flake lock` could not fetch the private agents-workspace archive;
  the authenticated local GitHub credential supplied `access-tokens` without
  exposing its value. The repo wrapper is NUC-only despite older local wording.
- Linux evaluation caught and now covers nested source-path context, invalid
  canonical-stack reapplication in the final package, store-context regexes in
  package assertions, generated unit indirection, and the installed Python
  site-packages layout.
- A mutable `github:...#nuc` input plus `--refresh` is not sufficient provenance
  protection: Nix may reuse a stale cached source after an API failure. Pin the
  live Git ref to the independently resolved current-main commit before any
  mutating rebuild.

## Remaining work

- Publish the current-main pinning guard.
- Rotate the exposed Kilo credential, update its encrypted NUC payload, then
  rebuild the published revision, dry-activate, deploy, and read back exact
  revisions and runtimes.
- Run live acceptance and capture the user-visible demo.

## Commits

- `b17d4e13c..4bfcca18f`: inherited red/green external cron ownership and
  deployment-readback hardening range.
- `e24f3eebe..e1d0d462c`: production overlay integration plus target-discovered
  red/green packaging and assertion fixes.
