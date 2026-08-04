# Worklog: bump-moshi-0.2.70

Status: active

## Objective

Update the shared Moshi hook pin from 0.2.69 to official upstream 0.2.70, land it on `origin/main`, deploy MacTraitor-Pro and NUC, and prove both services are healthy and report 0.2.70.

## Decisions

- Preserve the dirty canonical checkout; work from a clean sibling worktree based on `origin/main`.
- Update all four published platform hashes because the shared module supports Darwin and Linux on both architectures.

## Evidence

- `https://cdn.getmoshi.app/hook/latest/version.txt` returned `v0.2.70` on 2026-08-04.
- Current `origin/main` pins 0.2.69.
- `nix store prefetch-file --json` fetched all four official 0.2.70 archives and produced the hashes now pinned in `modules/services/moshi/default.nix`.
- `hey check` passed the Darwin configuration and repository checks; its formatting and pre-commit changed-file subchecks were no-ops, so they are not counted as independent proof.
- `hey nuc-wt build` built `/nix/store/d3090fa40kbzxwnhxjl5n5v52wmcp9h3-nixos-system-nuc-26.11.20260714.18b9261`, including `moshi-hook-0.2.70`.

## Reviews

- Plan gate: default Claude reviewer stopped at ACP `session/new` with `RUNTIME: Authentication required`; no findings produced.
- Plan fallback: OpenCode reviewer exited before ACP initialization because the `opencode-ai` postinstall runtime is missing; no findings produced.
- Manual scope review: one upstream version and its four official archive hashes; no behavior or interface change.

## Feedback

None.

## Remaining work

- Validate, commit, reconcile, and land.
- Deploy and verify MacTraitor-Pro and NUC.

## Commits

Pending.
