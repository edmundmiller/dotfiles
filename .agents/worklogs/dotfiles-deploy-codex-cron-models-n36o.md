# Worklog: dotfiles-deploy-codex-cron-models-n36o

Status: active

## Objective

Deploy agents-workspace `1d27591` to the NUC. Stop only when all live model-backed Hermes cron jobs use `openai-codex/gpt-5.6-{luna,terra,sol}`, script-only jobs remain model-free, profile auth succeeds, timers are active, and source branches are pushed/current.

## Decisions

- Use a clean worktree from `origin/main`; preserve unrelated dirt in the primary checkout.
- Update only the `agents-workspace` flake input.
- Use Luna for frequent mechanical jobs, Terra for normal tool-heavy jobs, and Sol for hard repair/synthesis.

## Evidence

- Agents-workspace model commit `1d27591` and independent-auth policy follow-up `8682e89` are pushed to `origin/main`.
- Canonical Python contract and Hermes Nix checks passed before deployment.
- NUC SSH and passwordless sudo work; live cron state was audited before migration.
- `hey nuc-wt build` built `/nix/store/1fmgc8lm8sp7jqh6ij0q5la5bq9z6kjw-nixos-system-nuc-26.11.20260714.18b9261`.
- `hey nuc-wt` dry activation completed; only expected Hermes Betty tick and Home Manager unit transitions were reported.

## Reviews

- Plan review: Claude and Gemini both failed at ACP `session/new` with `RUNTIME: Authentication required`; no findings were produced. This is a repeated repository tooling blocker. Proceed with the user-authorized, lockfile-only deployment and live verification; retry the landing gate.
- Landing review: pending.

## Feedback

None.

## Remaining work

- Commit/push lockfile and worklog, then deploy and verify runtime/auth.
- Land branch, close issues, tag.

## Commits

None.
