# Worklog: ci-speedup

Status: complete

## Objective

Reduce GitHub Actions CI critical-path time by removing the serial binary-cache
upload, separating Linux checks, and limiting Darwin-only coverage to main
pushes and manual runs; stop the sandbox-incompatible `hey-active-nix` hook
from running in the Nix pre-commit check. Stop when the requested checks pass
and the branch is pushed.

## Decisions

- Follow the approved CI job split and cache-action removal design.
- Keep `fetch-depth: 0` only where `qa-changed` needs the base diff.
- Use the pre-push stage for `hey-active-nix`, matching the runtime-drift hooks.
- `hey agent-start` is unavailable in this checkout because its Nix shebang
  points to `/run/current-system/sw/bin/nix`, which does not exist; use direct
  Nix commands requested by the task and record this environment blocker.
- The direct `python3 bin/agent-quality start` fallback created receipt
  `/home/ubuntu/.local/state/dotfiles-agent-runs/0d86eb19909c/20260819T160436Z-d699a9522dd7.json`
  for the Git-backed branch.

## Evidence

- Repository instructions read: `AGENTS.md`, `docs/agent-guardrails.md`,
  `AGENT_WORKFLOW.md`, and `openwiki/quickstart.md`.
- Authoritative CI timing and design supplied in the task.
- CI workflow and `flake.nix` hook-stage edits applied on branch
  `devin/1787155419-ci-speedup`.
- `nix --accept-flake-config build --no-link --print-build-logs` passed for
  the five requested Linux checks; the pre-commit run passed treefmt and all
  configured hooks.
- Both requested Darwin `nix eval` commands printed `"OK"`.
- `nix run nixpkgs#actionlint -- .github/workflows/ci.yml` passed.
- The requested Herdr VM build reached the derivation and was blocked by the
  runner's missing `kvm` system feature; `/dev/kvm` exists but the runner user
  is not in group `kvm`, and Nix reports available features without `kvm`.

## Reviews

None.

## Feedback

The repository `bin/hey` shebang assumes `/run/current-system/sw/bin/nix`,
which is absent on this Linux runner; the documented `hey` workflow cannot
start here.

## Remaining work

The VM check requires a runner with Nix `kvm` feature access; no source
changes remain.

## Commits

- `227e9645` — `ci: speed up GitHub Actions checks`
