# Worklog: workspace-ttp.1

Status: active

## Objective

Provide an Edmund-only NUC Factory ACP runtime with a canonical `claude-opus-5` settings file and a host-local Factory authentication path. Stop before Buzz provisioning; success requires a deployed NUC no-tools authenticated ACP canary.

## Decisions

- Reuse the existing `bunx --bun droid` launcher pattern rather than introducing an unverified package source.
- Keep Factory authentication in a dedicated NUC state directory. Do not copy local Factory credentials or create a Buzz identity/channel before the NUC canary.

## Evidence

- Local direct ACP canary selected `claude-opus-5` through a credential-free settings overlay and returned an authenticated no-tools response.
- `ssh nuc 'command -v droid'` showed no host Droid command before this change.
- `hey agent-start` rejected this Git-only repository despite the documented Git-only workflow; fallback isolated Git worktree: `/Users/emiller/src/personal/dotfiles-product-pass`.
- `hey nuc-wt switch` installed the committed runtime as Nix generation 211 with exit code 0. Post-deploy warnings about inactive Hermes units are unrelated to the Factory runtime.
- The deployed `factory-product-pass-canary` initialized Factory ACP and returned the exact no-tools sentinel `FACTORY_ACP_READY Opus 5` in 6.42 seconds.
- `hey agent-audit-tests` passed `test-confidence`.

## Reviews

- Plan gate attempted with the default reviewer; its ACP client failed at `session/new` with `RUNTIME: Authentication required`. The deprecation warning was unrelated. No heterogeneous review is available until a reviewer is authenticated.
- Landing gate attempted with the default reviewer and failed at ACP `session/new` with the same `RUNTIME: Authentication required` error; no reviewer-authenticated landing review is available.
- Code simplification review found no changes warranted: the NUC wrapper, generated settings, state directory, and no-tools canary are all required.

## Feedback

- `hey agent-start` incorrectly demands jj initialization for a Git-only repository, contradicting its documented Git-only workflow.

## Remaining work

- The NUC prerequisite is complete. Product Pass Buzz identity/channel provisioning remains in the agents-workspace route task.

## Commits

- `7e5bc3345 feat(nuc): add isolated Factory ACP canary`
