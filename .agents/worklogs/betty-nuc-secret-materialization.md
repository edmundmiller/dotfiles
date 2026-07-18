---
purpose: Track Betty NUC secret materialization repair and landing evidence.
applies_to: Betty Hermes cron secret injection on the NUC.
entrypoint: hosts/nuc/default.nix and its Hermes cron executor check.
verification: Build, deploy with hey nuc, then verify key presence and auth booleans.
update_when: Betty secret ownership, materialization, or executor identity changes.
---

# Worklog: betty-nuc-secret-materialization

Status: complete

## Objective

Materialize Betty's Discord, Life Time, and Linear secrets into her root-generated service environment before cron execution. Stop after focused checks, NUC deployment, boolean presence/auth proof, commit, rebase, push, and upstream verification. Never trigger booking or messaging.

## Decisions

- Keep `/etc/opnix-token` root-owned; root activation already owns secret materialization.
- Derive 1Password references from the pinned Betty agent specification to avoid duplicated references.
- Give only Betty's executor the token-file group and export the token in its wrapper because the Lift prompt itself invokes `op read`.
- Verify only key names/booleans and non-secret authentication outcomes.

## Evidence

- Live NUC: `/etc/opnix-token` is `root:onepassword-secrets 0640`; `emiller` cannot read it.
- Live NUC: root `op whoami` and all four Betty references succeed with output suppressed.
- Live NUC: `/run/hermes-betty-env/secrets.env` lacks the four required keys.
- Live NUC: recent cron logs show unauthenticated `op` reads and `No accounts configured`.
- Red: remote `nuc-hermes-cron-executors` failed for missing root token use and four generated env keys.
- Green: rebased `hey nuc-wt build` and remote `nuc-hermes-cron-executors` passed.
- Deploy: `hey nuc` switched to `/nix/store/nzshlypdkhmr9bqvjr48wzq070cn61r9-nixos-system-nuc-26.11.20260714.18b9261`.
- Live NUC: all four required values are non-empty; Discord auth returned HTTP 200 and Linear auth returned 2xx. Values were never printed.
- Built-in `hermes-runtime-smoke.service` is masked, so it was not counted as verification.
- Another worktree redeployed generation 1147 at 18:40, replacing the fixed generation before the 18:43 natural tick; that tick reproduced 12 auth errors. Land upstream, redeploy, and recheck.
- `hey agent-audit-tests` passed. `hey agent-finish` passed its substantive checks but repo-quality failed because no prek config exists; direct `nixfmt --check` passed.
- Follow-up expected-failure coverage captured missing token access; remote system build and focused Nix check passed after adding the wrapper and supplementary group.
- Natural tick at 18:59:20 finished successfully with exit 0 and zero 1Password/auth errors.
- A subsequent upstream deploy changed the generation to `/nix/store/xmsgbpzkybbj0wcvvq8q24gi1gmwgdk9-nixos-system-nuc-26.11.20260714.18b9261`; the token group, wrapper, and four non-empty keys remained present.

## Reviews

- Plan: Claude and Gemini gates both stopped at ACP session creation with `RUNTIME: Authentication required`; no findings produced. Proceeding under the explicit delegated scope with red/green coverage and live NUC evidence.
- Landing: Claude and Gemini gates repeated `RUNTIME: Authentication required`; no findings produced. Manual semantic review found no scope, secret-exposure, or atomicity issues.

## Feedback

- Shared prek hooks expect absent `.pre-commit-config.yaml`; commits require the hook's documented `PREK_ALLOW_NO_CONFIG=1` fallback after explicit checks.
- `hey nuc` attempts a masked `hermes-runtime-smoke.service`; direct live checks remain necessary.

## Remaining work

None.

## Commits

- `a1e7318b99` test(nuc): capture Betty secret outage
- `f21c84b569` fix(nuc): materialize Betty runtime secrets
- `368bc6943` test(nuc): capture Betty token access gap
- `60ce35994` fix(nuc): authorize Betty 1Password reads
