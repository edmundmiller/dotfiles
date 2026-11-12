---
purpose: Explain how self-hosted Renovate runs in this repo and how to verify it.
applies_to: Renovate config, the scheduled Action, or dependency-update PR triage.
entrypoint: Read renovate.json, then .github/workflows/renovate.yml.
verification: Run the Renovate config validator and tests.test_package_policy, then inspect hosted runs after publication.
update_when: The runner, token owner, schedules, grouping, or hash-refresh command changes.
---

# Renovate

This repository self-hosts Renovate through `.github/workflows/renovate.yml`.
It does **not** use the Mend Renovate GitHub App. Do not install that app here;
a second runner would duplicate PRs.

## How it runs

- Schedule: Actions cron `17 10 * * *`. That is 04:17 CST and 05:17 CDT.
- Config schedule: Monday 04:00 through 08:59 America/Chicago. The daily Action
  still runs. Existing branches can update outside that window. Routine updates
  need Dependency Dashboard approval before Renovate creates a branch or PR.
  The types-only pilot below is the sole routine exception. Dashboard selection
  chooses work to prepare; it is not a required safety gate for pilot admission.
- Auth: repository secret `RENOVATE_TOKEN` (a fine-grained PAT). Pull requests
  and the Dependency Dashboard issue are authored as that token's user
  (`edmundmiller` today), **not** `app/renovate`.
- Hash refresh: `postUpgradeTasks` runs
  `nix run --accept-flake-config .#renovate-update-nix-hashes`.
  Only the runner's `RENOVATE_ALLOWED_COMMANDS` authorizes execution. The
  repository config cannot grant that permission.
- Herdr and Hunk use `.github/workflows/renovate-patch-repair.yml` for patch
  validation and repair. That workflow does not merge or enable GitHub automerge.

## Expected PR shape

These are update proposals. Only the types-only pilot can be admitted automatically.

| Branch / group                            | Contents                                            |
| ----------------------------------------- | --------------------------------------------------- |
| `renovate/lock-file-maintenance`          | Weekly lock maintenance, including `flake.lock`     |
| `<manifest directory> dependencies`       | Non-major npm/bun runtime and development updates   |
| `renovate/pi-workspace-dependencies`      | Pi workspace updates sharing the root `bun.lock`    |
| `renovate/github-actions`                 | Non-major Actions and digest pins                   |
| `renovate/nix-flake-inputs`               | Versioned flake inputs                              |
| `renovate/repo-local-nix-package-patches` | Regex-managed Nix package patches plus hash refresh |
| `renovate/herdr`, `renovate/hunk`         | Overlay/harness and flake tag                       |
| `renovate/callstack-types-patches`        | Future stable callstack `@types/bun` patches        |
| Major updates                             | Explicit dashboard selection, separate from minors  |

Grouping runtime and development dependencies together avoids competing updates
to the same lockfile. Pi subpackages share one group even where legacy npm locks
also exist. Other packages remain separate so one broken package does not block
all JavaScript updates. Routine proposals retain the three-day release age,
two-PR hourly limit, four-PR concurrent limit and conflict-only rebases.
Approved proposals create PRs immediately because bare `renovate/**` pushes do
not start CI. `prCreation=not-pending` would wait for checks before creating the
PR event that starts them.

Security alerts remain enabled, bypass routine dashboard approval, scheduling,
release age and rate limits, and never automerge. Their default per-dependency
branches can still span packages. Do not suppress a security fix just to reduce
the count. Dependabot is a separate source and is not controlled by this file.

`pruneStaleBranches=false` preserves orphan branches and prevents stale-PR
autoclosure during this regrouping. Existing PR reconciliation and closure need
separate approval. In particular, #271 and its branch must stay open/preserved.
This setting is not a general freeze on updates to active Renovate branches.

Unversioned flake pins and private inputs (`agents-workspace`, `tnote`) are not
individual PRs. Bump those with `hey upgrade` when the PAT cannot see the repo.

## Admission and automerge

Renovate automerge is disabled for every update class, including lock maintenance
and security fixes. Follow [candidate CI](candidate-ci.md) for authorized
publication. A dependency PR is an optional review artifact, not a required
landing route. Preserve provider-bound checks and the empty bypass list.

Disabling Renovate automerge does not cancel existing GitHub auto-merge requests.
Inspect those separately and cancel them only with explicit approval.

Renovate's [branch automerge](https://docs.renovatebot.com/noise-reduction/)
requires checks on its branch, but `ci.yml` only handles main/candidate pushes
and PR events. It does not submit `candidate/BASE/SHA` or verify that candidate's
latest workflow attempt. Adding CI on Renovate branches alone would still omit
that admission step. GitHub PR squash/rebase/merge methods create or rewrite
commits rather than normally fast-forwarding main to the tested candidate SHA.
The former patch-repair `gh pr merge --auto --squash` step was therefore not a
compatible substitute, even with green required contexts.

There is also a package evidence gap. The hash-refresh command detects changed
Nix files, not JavaScript-only manifest or lock changes. It neither regenerates
all `bun.nix` files nor refreshes every `npmDepsHash` after lock-only updates.
The portable validation selector does not build every affected Nix package.
An artifact error or manifest-only green PR must not be admitted unchanged.
Package integration must regenerate the owner's actual locks, generated Nix
dependencies and hashes, run focused tests and build the affected package before
submitting fresh candidate CI. This policy change does not repair existing PRs.

## Types-only candidate pilot

Only future stable `@types/bun` patches in callstack-diff and their required
`bun-types` patch dependency skip Dashboard selection and can land unattended.
Native Renovate automerge remains off. `.github/workflows/renovate-admission.yml`
uses trusted default-branch code and `scripts/candidate_ci.py` for exact-candidate
submission and normal fast-forward landing. No merge API or deployment is used.

Only this fixed proposal branch is exempt from concurrent proposal limits so a
held backlog above the ordinary cap cannot starve the pilot. The ordinary
four-PR cap, two-per-hour limit, release age and schedule remain unchanged.

After a successful Renovate run, preparation reconstructs the allowed manifest
edit on current main, resolves `bun.lock` with pinned Bun and regenerates
`bun.nix` with pinned bun2nix. Installation scripts are disabled. Preparation has
no write credential. A separate job revalidates the artifact and reproducibility
and commits only those three files before supplying the publishing credential.

The dedicated proposal branch and exact pilot labels are required, but labels
and author identity are not authorization. The controller checks the semantic
manifest and lock diff, same-major/minor increasing stable patch and three-day
registry release age of both packages. Extra dependencies, registry changes,
production changes, scripts or extra files are held. Any additional hold/security
label blocks admission. Proposals created before the workflow's introduction,
including #266/#236 and #271, are excluded. No existing PR is merged or closed.

The shared selector routes callstack manifest/lock/generated-file changes to a
Nix check with frozen development installation, `lint:setup`, deterministic lint
and tests, and generator reproducibility. The same check builds the production
package and exercises its installed CLI against a known call-tree fixture.
Live-model evals are excluded. Linux evidence does not authorize Mac activation.

The publishing job uploads a SHA-bound `types-candidate-ATTEMPT` record. On CI
completion the controller verifies the record and its successful publisher attempt,
the latest exact-candidate CI attempt and both Actions checks from provider 15368.
An unrelated candidate at the same base blocks selection. Main/proposal movement,
artifact failure and failed/missing checks hold admission. A moved main requires
regeneration on a later Renovate run; no old green result certifies a new SHA.
Failed candidates remain as evidence and need triage before reusing that base.

Only publishing steps receive the existing `RENOVATE_TOKEN`. Its real permissions
must be verified in the separately authorized hosted rollout. Default
`GITHUB_TOKEN` pushes cannot trigger downstream push CI. Missing permission stops
admission; do not broaden credentials or change repository rules automatically.

Pi, acpx, runtime changes and all-owner lock maintenance stay outside the pilot.
The generic refresh still misses JS-only hashes for other owners. Acpx needs
`npmDepsHash` refresh and Pi's legacy npm `workspace:*` artifact failure needs
repair before either can be admitted. No backlog cleanup, token/settings change,
Darwin activation or deployment is included.

## Verify

Locally run `renovate-config-validator --strict --no-global renovate.json` with the runner's
Renovate version, `python3 -m unittest tests.test_package_policy`, and
`hey check renovate.json .github/workflows/renovate-patch-repair.yml docs/runbooks/renovate.md tests/test_package_policy.py`.
Configuration validation does not prove artifact generation, hosted builds, or
automatic admission. Do not run Renovate against the live repository just to
validate local configuration.

For the pilot, also run `python3 -m unittest tests.test_renovate_admission
tests.test_candidate_ci tests.test_validation` and
`hey check scripts/renovate_admission.py .github/workflows/renovate-admission.yml
packages/callstack-diff`. Controller tests use disposable Git remotes and simulated
GitHub/registry/tooling. They do not prove live token permissions or hosted landing.
The Nix package check uses the actual pinned tools and installed CLI.

After separately authorized publication, inspect the Dependency Dashboard and
latest scheduled Renovate run. Check that non-pilot routine updates wait for selection,
package groups do not overlap locks, and artifact failures remain visible.
Manual workflow dispatch and dashboard actions cause external writes and require
their own authority. A green Renovate run can still report `renovate/artifacts`
failures on individual proposals.

Live checks: `gh issue list --search 'Dependency Dashboard in:title'` and
`gh run list --workflow=renovate.yml --limit 5`.
