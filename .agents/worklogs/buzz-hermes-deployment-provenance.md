# Worklog: buzz-hermes-deployment-provenance

Status: active

## Objective

Stamp each NUC generation with the exact dotfiles revision and locked agents-workspace revision. Done when a pure regression exercises the worktree-without-`.git` path, the focused checks and remote NUC build pass, the scoped commits are pushed, the NUC is switched from the pushed revision, and live readback reports both exact revisions without disturbing sibling services.

## Decisions

- Work in an isolated clean worktree based on current `origin/main`; preserve the dirty canonical checkout byte-for-byte.
- Use one exact labeled `system.configurationRevision`: `dotfiles=<revision>;agents-workspace=<revision>`.
- Generate the worktree revision marker only in the remote synced snapshot because `.git` is intentionally excluded.
- Refuse dirty `dry-activate`, `test`, and `switch`; dirty `build`/`vm` snapshots are labeled `<HEAD>-dirty`.
- Materialize clean snapshots from `git archive <HEAD>`, isolate every run by UUID, and retain only the five newest revision-scoped snapshots.

## Evidence

- Pre-change live readback: generation 1417 has `system.configurationRevision = null`; the deployed flake lock pins agents-workspace `6feff320a898aedf25bc0720968a5cbc5d347c30`.
- Red observed before the test commit: `nuc-deployment-provenance` failed with `NUC deployment provenance must have a pure resolver`. The committed test used the repository's green expected-failure convention until the implementation commit flipped it; the committed test revision itself was not red.
- Green: `nix develop --command nu bin/tests/hey-nuc-deploy-mode.nu` passed.
- Green: `nix run .#hey -- check` passed every Darwin-compatible gate.
- Green: `nix run .#hey -- nuc-wt build` built the full NUC configuration through the `.git`-less synced-worktree path.
- Green: the focused Linux check passed and remote evaluation returned `dotfiles=eff3e325bdb5ea1934a31dfb4d2e482574c8705f;agents-workspace=6feff320a898aedf25bc0720968a5cbc5d347c30` before final reconciliation.
- Green after hardening: Darwin-safe `nuc-deployment-provenance` and `hey-nuc-deploy-mode` checks pass; the Linux/NUC-only integration assertion and deploy-mode check pass from the `.git`-less snapshot.
- Green: a dirty build through the production helper returned `/nix/store/910dxwrpihjrjqdrvw2aj29sarx2h2qq-nixos-system-nuc-26.11.20260714.18b9261` without activation. Its exact marker and config readback were `c3558f3efd0d13f9df711e418f40ce562543f5c9-dirty` and `dotfiles=c3558f3efd0d13f9df711e418f40ce562543f5c9-dirty;agents-workspace=6feff320a898aedf25bc0720968a5cbc5d347c30`.
- Green: the remote retention readback reported five revision-scoped snapshots and preserved `/tmp/dotfiles-worktree-emiller-trmnl-enrollment`.

## Reviews

- Automated heterogeneous plan gate attempted with `hey agent-review plan --active-model-family openai`; ACP session creation returned `RUNTIME: Authentication required`. The active durable goal and the bounded TDD seam are authoritative, so implementation proceeds with the exact reviewer-access blocker recorded.
- Automated heterogeneous landing gate hit the same `RUNTIME: Authentication required` blocker; an independent read-only repository review was requested instead.
- Independent review initially held the branch for fail-open evaluation, dirty-source mislabeling, shared-directory concurrency, shallow seam coverage, a Darwin integration-eval violation, working-tree TOCTOU, and unbounded `/tmp` retention. The hardening now fails closed, blocks dirty activation, archives the exact commit for clean runs, uses UUID snapshots, exercises the real marker helper and assume-unchanged case, gates NUC config integration to Linux, and bounds retention.
- `hey agent-audit-tests` passed test-confidence and `hey agent-finish` passed the worklog, repository checks, 56 agent-quality tests, 16 agent rules, 55 skills, instruction checks, and inventory checks.

## Feedback

- The deploy guard already knew the source HEAD, but the Nix evaluation could not see it after rsync excluded `.git`.
- The first retention-enabled dirty build exposed a missing trailing slash that nested the checkout and hid the marker writer; the production-shaped regression now covers the normalized source path.
- The first Linux sandbox run exposed `/usr/bin/env` shebang unavailability; generated remote marker commands now invoke `bash` explicitly.

## Remaining work

- Reconcile and push, deploy from the exact pushed revision, read back the live generation and six Hermes gateways, finish the landing gates, and tag the run.

## Commits

- `da9b24291` — `test(nuc): capture missing deployment provenance`
- `7b32c6c16` — `fix(nuc): stamp Buzz Hermes deployment revisions`
- `3555dd97a` — `fix(nuc): harden deployment provenance`
- `4d9bd73c3` — `docs(nuc): document provenance-safe deploys`
