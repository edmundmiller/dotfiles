# Worklog: buzz-hermes-deployment-provenance

Status: active

## Objective

Stamp each NUC generation with the exact dotfiles revision and locked agents-workspace revision. Done when a pure regression exercises the worktree-without-`.git` path, the focused checks and remote NUC build pass, the scoped commits are pushed, the NUC is switched from the pushed revision, and live readback reports both exact revisions without disturbing sibling services.

## Decisions

- Work in an isolated clean worktree based on current `origin/main`; preserve the dirty canonical checkout byte-for-byte.
- Keep `system.configurationRevision` as the dotfiles Git revision and expose the paired agents-workspace revision in one machine-readable provenance fact.
- Generate the worktree revision marker only in the remote synced snapshot because `.git` is intentionally excluded.

## Evidence

- Pre-change live readback: generation 1417 has `system.configurationRevision = null`; the deployed flake lock pins agents-workspace `6feff320a898aedf25bc0720968a5cbc5d347c30`.

## Reviews

- Automated heterogeneous plan gate attempted with `hey agent-review plan --active-model-family openai`; ACP session creation returned `RUNTIME: Authentication required`. The active durable goal and the bounded TDD seam are authoritative, so implementation proceeds with the exact reviewer-access blocker recorded.
- Landing review pending.

## Feedback

- The deploy guard already knows the source HEAD, but the Nix evaluation cannot see it after rsync excludes `.git`.

## Remaining work

- Add the failing pure regression, implement the provenance seam, validate, land, deploy, and read back.

## Commits

- None yet.
