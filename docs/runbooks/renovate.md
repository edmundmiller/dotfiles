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
  This selects work to prepare, not permission to publish it to main.
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

These are update proposals, not automatically admitted commits.

| Branch / group                            | Contents                                            |
| ----------------------------------------- | --------------------------------------------------- |
| `renovate/lock-file-maintenance`          | Weekly lock maintenance, including `flake.lock`     |
| `<manifest directory> dependencies`       | Non-major npm/bun runtime and development updates   |
| `renovate/pi-workspace-dependencies`      | Pi workspace updates sharing the root `bun.lock`    |
| `renovate/github-actions`                 | Non-major Actions and digest pins                   |
| `renovate/nix-flake-inputs`               | Versioned flake inputs                              |
| `renovate/repo-local-nix-package-patches` | Regex-managed Nix package patches plus hash refresh |
| `renovate/herdr`, `renovate/hunk`         | Overlay/harness and flake tag                       |
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

Recommended next decision: keep Renovate as an update proposer and authorize a
separate, narrow candidate-admission controller only after package generation
and hosted build coverage are complete for an explicit dependency allowlist.
That controller must reconcile onto exact main, submit the existing candidate
route, require its latest hosted checks from the expected provider, and normally
fast-forward the same passing SHA. A moved main needs a new candidate. No blanket
bypass, mandatory PR, merge API, or deployment permission is needed. Native
Renovate automerge stays off; this controller is not implemented or enabled here.

## Verify

Locally run `renovate-config-validator --strict --no-global renovate.json` with the runner's
Renovate version, `python3 -m unittest tests.test_package_policy`, and
`hey check renovate.json .github/workflows/renovate-patch-repair.yml docs/runbooks/renovate.md tests/test_package_policy.py`.
Configuration validation does not prove artifact generation, hosted builds, or
automatic admission. Do not run Renovate against the live repository just to
validate local configuration.

After separately authorized publication, inspect the Dependency Dashboard and
latest scheduled Renovate run. Check that routine updates wait for selection,
package groups do not overlap locks, and artifact failures remain visible.
Manual workflow dispatch and dashboard actions cause external writes and require
their own authority. A green Renovate run can still report `renovate/artifacts`
failures on individual proposals.

Live checks: `gh issue list --search 'Dependency Dashboard in:title'` and
`gh run list --workflow=renovate.yml --limit 5`.
