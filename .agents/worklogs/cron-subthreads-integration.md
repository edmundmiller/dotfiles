# Worklog: cron-subthreads-integration

Status: active

## Objective

Integrate every actionable Hermes cron sub-thread with no new merge commits, prove focused tests and a NUC build, deploy one serialized generation, and close only beads with fresh live or natural-run evidence.

## Decisions

- Keep workers' red/green commits when still relevant; rebase/cherry-pick onto current main and use fast-forward-only landing.
- Treat agents-workspace as canonical runtime source and dotfiles as host wiring.
- Do not land stale tracker-only closure commits before their acceptance evidence exists.
- Batch compatible host changes into one NUC generation.

## Evidence

- Current agents-workspace main and dotfiles origin/main fetched 2026-07-16.
- Branch ancestry and `git cherry` audited for all cron sub-threads.
- Agents-workspace Amos model contract passed via Python and `.#checks.aarch64-darwin.amos-cron-model-contract`; commits landed FF-only on main.
- Dotfiles focused Python tests passed for executor wiring and Radar runtime.
- `.#checks.aarch64-darwin.nuc-hermes-cron-external-executor` executes five tests against the patched pinned Hermes source; no skip-only proof remains.
- NUC x86_64 checks passed: executor wiring, Scintillate runtime access, Radar runtime, and external executor reporting.
- Initial NUC check exposed immutable-store chmod from copying symlinked Hermes files. The integrated fix dereferences them into writable output; all four checks then passed.
- Full NUC build passed after the final rebase onto dotfiles main: `/nix/store/2gvvj6akdnx6ia75b0rg8x13nhpgbrz3-nixos-system-nuc-26.11.20260714.18b9261`.
- `hey agent-audit-tests` passed for the changed executor/runtime tests.
- `hey agent-finish` passed test confidence, inventory, agent-quality tests, and drift checks. Its repo-quality subcheck failed because the repository has neither `prek.toml` nor `.pre-commit-config.yaml`; formatting and hook commands stopped at that missing baseline configuration before examining task files.
- Current NUC switch and natural-run proof still required after landing.

## Reviews

- Plan review: required gate attempted three ways on 2026-07-16. Claude returned `Authentication required`; Gemini's ACP adapter passed unsupported `acp`; grok-build could not spawn `grok agent stdio`. No independent reviewer was available. Continue with explicit branch, test, build, and live-runtime evidence; rerun landing review before completion.
- Landing review: Claude gate retried after the full build and again returned `Authentication required` before producing findings.

## Feedback

- `hey agents-rollout` still targets missing `~/.openclaw/workspace`; use explicit repo paths for this integration.

## Remaining work

- Run landing gates and land dotfiles FF-only.
- Switch the NUC once from integrated main.
- Verify live units, ownership, timer-aware status, stable natural ticks, and due-run artifacts.

## Commits

- Agents-workspace `273fa9a`, `52b5eeb` — Amos model regression/fix; FF-only on main.
- Dotfiles `4f9a37fec` — remove duplicate Amos cron ownership repair.
- Dotfiles `8e04a6a47`, `e8db61d91` — Scintillate executor regression/fix.
- Dotfiles `4ecbf3160`, `3c155aaf9` — timer-aware Hermes health regression/fix.
- Dotfiles `4b2923e55` — execute external-executor regression in Nix checks.
- Dotfiles `7692da380` — pin integrated agents-workspace main.
- Dotfiles `e85c3568f` — dereference patched Hermes CLI out of the immutable store.
