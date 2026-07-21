# Worklog: hermes-cron-tick-cadence

Status: complete

## Objective

Make all four NUC Hermes external cron tick timers poll every 60 seconds with a
one-second accuracy window and no per-iteration randomized delay. Stop after a
regression test proves the contract, the NUC build and switch succeed, live unit
properties match it, natural timer firings remain healthy, and task-only commits
are current on the upstream branch.

## Decisions

- Canonical source is `hosts/nuc/default.nix`; live NUC systemd state is the
  deployment authority.
- Use `OnUnitActiveSec=60s`, `AccuracySec=1s`, and
  `RandomizedDelaySec=0s`. Systemd documents that accuracy may defer within its
  window and randomized delay is added on every iteration, so both old values
  worsened scheduler latency and drift.
- Extend the existing Nix executor contract across all four timers. Keep its
  expected-failure marker in the test-only commit, then flip it with the fix.
- Never invoke `hermes cron tick` or any Hermes job manually. Treat natural
  timer activation and job timing as separate evidence from deployment state.

## Evidence

- Run receipt:
  `/Users/emiller/.local/state/dotfiles-agent-runs/f59f03899bcf/20260721T232730Z-6717805a6f3c.json`.
- 2026-07-21 pre-change live state: NUC hostname/kernel verified; all four
  `hermes-*-cron-tick.timer` units are enabled and active with
  `AccuracyUSec=1min` and `RandomizedDelayUSec=30s`; source uses
  `OnUnitActiveSec=5min`.
- Red regression: remote
  `.#checks.x86_64-linux.nuc-hermes-cron-executors` failed only with
  `Hermes cron timers must tick every 60 seconds without scheduling jitter.`
- After rebasing onto current `origin/main`, `hey nuc-wt build` produced
  `/nix/store/30z76v2q6lg80spd063gjxz7db7arnww-nixos-system-nuc-26.11.20260714.18b9261`;
  remote `.#checks.x86_64-linux.nuc-hermes-cron-executors` passed.
- Dry activation predicted restarts of only the four cron timers and the
  upstream Home Manager unit. `hey nuc-wt switch` activated that same store
  path.
- Post-switch live state: every timer is enabled and active with
  `OnUnitActiveSec=60s`, `AccuracySec=1s`, and `RandomizedDelaySec=0s`.
- Natural timer proof: Amos, Betty, and Radar started successfully at 18:40:56
  and 18:41:57 CDT (61 seconds); Scintillate started successfully at 18:40:33
  and 18:41:33 CDT (60 seconds). This proves ticker timing, not yet a full
  60-minute completion-based job cycle.
- `python3 bin/agent-quality audit-tests ...` passed. The legacy
  `tests.test_hermes_cron_executors` source-string test fails on current
  `origin/main`: it expects `HERMES_MCP_BEARER_TOKEN_LINEAR` while canonical
  source now declares `LINEAR_API_KEY`. This pre-existing drift is unrelated to
  the timer change; the focused Nix test exercises the deployed contract.
- `python3 bin/agent-quality finish ...` passed worklog validation, Darwin
  evaluation, 15 workflow-engine tests, test-confidence, inventory drift,
  tmux, package-harness, package-policy, and ast-grep checks. `repo-quality`
  failed only because both its treefmt and hook commands route through Prek,
  while this repository has neither `prek.toml` nor
  `.pre-commit-config.yaml`.
- Direct landing was verified at `170a7d0a53`: local `main` and
  `origin/main` were equal, and the task tip was an ancestor of both.
- `br sync --flush-only` reported no dirty issues and produced no tracked
  changes.

## Reviews

- Plan gate attempted with the required different-family reviewer. Claude and
  the single Gemini fallback both stopped at ACP session creation with
  `RUNTIME: Authentication required`; no review findings were produced. The
  gate blocker is recorded rather than bypassed silently. Scope remains the
  four timer properties plus their existing focused Nix contract.
- Landing review is blocked by the same ACP authentication boundary as the plan
  gate. No authenticated heterogeneous reviewer is available; after the Claude
  failure and one Gemini fallback, the workflow forbids looping providers.

## Feedback

- `hey agent-start` currently dispatches only the exported zero-argument `main`
  and rejects the documented subcommand. The source command
  `python3 bin/agent-quality start ...` produced the required receipt.
- ACPX has no authenticated heterogeneous reviewer in this runtime: both the
  default Claude route and one Gemini fallback failed before review.
- The installed Prek hook has no repository config. The first commit attempt
  stopped before examining files; `PREK_ALLOW_NO_CONFIG=1` used Prek's stated
  no-config behavior after the focused Nix check passed.

## Remaining work

None.

## Commits

- `aa12264dd9 test(nuc): capture Hermes cron ticker drift`
- `318e7aee0b fix(nuc): poll Hermes cron every minute`
- `170a7d0a53 docs(worklog): record Hermes cron tick rollout`
