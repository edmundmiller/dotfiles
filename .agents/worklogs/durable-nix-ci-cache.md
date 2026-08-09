# Worklog: durable-nix-ci-cache

Status: active

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

## Reviews

None yet.

## Feedback

None.

## Remaining work

- Configure Linux CI installers with `accept-flake-config = true`.
- Validate the workflow and run focused repository checks.
- Push and inspect a first CI run and an unchanged rerun.

## Commits

None yet.
