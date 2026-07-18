# Worklog: dotfiles-deploy-codex-cron-models-n36o

Status: complete

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
- Final `hey nuc` switch activated `/nix/store/jskqp0gm8hrhwwfjrk9y6gjsvgg31v4x-nixos-system-nuc-26.11.20260714.18b9261`.
- Live audit: 15 model-backed jobs all use `openai-codex/gpt-5.6-{luna,terra,sol}`; one script-only job remains model-free; four cron timers are active and tick services report success.
- Betty/Terra and Scintillate/Sol direct probes returned `AUTH_OK`.
- Amos and Radar completed independent device-code authorization. All four profile Codex access-token fingerprints are distinct.
- Fresh direct probes returned `AUTH_OK`: Amos/Sol, Betty/Terra, Radar/Luna, and Scintillate/Sol.
- Final live audit: 15 model-backed jobs, one script-only job, zero model violations, and four active cron timers.
- `hey agent-audit-tests flake.lock` and `hey agent-finish --changed flake.lock --worklog .agents/worklogs/dotfiles-deploy-codex-cron-models-n36o.md` passed.

## Reviews

- Plan review: Claude and Gemini both failed at ACP `session/new` with `RUNTIME: Authentication required`; no findings were produced. This is a repeated repository tooling blocker. Proceed with the user-authorized, lockfile-only deployment and live verification; retry the landing gate.
- Landing review: retry reached ACP `session/new` and failed with `RUNTIME: Authentication required`; no findings were produced. Runtime, deployment, auth, and repository gates passed independently.

## Feedback

- Commit/rebase hooks invoke `prek` but this checkout has no `.pre-commit-config.yaml`; commits used the hook's explicit `PREK_ALLOW_NO_CONFIG=1` recovery. NUC build and runtime checks remain the exercised gates.
- Live JSON backups created with `sudo` were root-owned and blocked activation ownership normalization. Their ownership was corrected to `emiller:users`; the subsequent switch passed.

## Remaining work

- None for this migration. Hermes CLI teardown exit 134 after a successful Scintillate response is tracked separately as `workspace-hermes-codex-probe-teardown-y51`.

## Commits

- `d23b77303` - deploy Codex cron model pin.
- `60ae9aa295` - pin independent-auth policy follow-up.
- `4cb9c3273d` - checkpoint Codex cron auth and deployment evidence.
