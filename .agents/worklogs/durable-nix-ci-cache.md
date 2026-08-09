# Worklog: durable-nix-ci-cache

Status: complete

## Objective

Make Linux GitHub Actions consume the durable Numtide binary cache declared by the flake, then prove an unchanged rerun restores outputs instead of rebuilding them.

## Decisions

- Reuse the existing public `cache.numtide.com` substituter and signing key; no credential or paid cache expansion is needed.
- Configure the Nix installer to accept the repository's flake config. This fixes the source warning instead of adding cache flags to each build command.
- Keep Magic Nix Cache for repository-specific outputs; Numtide provides durable upstream OMP and Herdr outputs outside GitHub's 10 GB cache quota.

## Evidence

- Baseline CI run `31291245919`, Linux job `93188686960`: `Run flake checks` took 34m03s; pre-commit took 24m01s and built 999 derivations.
- The same OMP derivation was rebuilt in adjacent runs `31289493527` and `31291245919`.
- Baseline logs warned that `extra-substituters` and `extra-trusted-public-keys` were ignored without `--accept-flake-config`.
- GitHub Actions held 10,000 caches totaling about 9.46 GB, near its default 10 GB repository limit.
- `https://cache.numtide.com/nix-cache-info` is public and reports `/nix/store`.
- First configured run `31293124524`, Linux job `93193686353`: passed in 4m53s. The six flake checks took 35.272s, 37.952s, 9.236s, 1.746s, 2.389s, and 2m52.893s.
- First-run logs contained zero untrusted-flake warnings and 743 Numtide cache references. OMP 17.2.11 was copied from `https://cache.numtide.com` instead of built.
- Unchanged rerun of `31293124524`, Linux job `93194895013`: passed in 5m00s. It again contained zero untrusted-flake warnings, 743 Numtide cache references, and restored the identical OMP store path from Numtide.
- `actionlint .github/workflows/*.yml`: PASS.
- `python3 bin/agent-quality inventory`: regenerated `docs/agent-quality.md` from `.agents/quality.json`.
- `hey agent-audit-tests`: PASS `test-confidence`.
- `hey agent-finish --worklog .agents/worklogs/durable-nix-ci-cache.md`: PASS after exercising Darwin evaluation, formatting, hooks, shell/package checks, 35 agent-quality tests, instruction checks, confidence checks, and inventory drift.

## Reviews

Cross-model review was not requested; `AGENT_WORKFLOW.md` makes it optional.

## Feedback

- Parked: the quality gate includes unrelated untracked files. The pre-existing 1.2 MB `audit-agent-worktrees.md` worklog caused an initial formatter and large-file failure; future gate tooling should accept explicit task paths.

## Remaining work

None.

## Commits

- `dd1eec291` `ci(nix): trust durable flake cache`
