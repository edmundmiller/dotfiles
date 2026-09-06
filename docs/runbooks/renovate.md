---
purpose: Explain how self-hosted Renovate runs in this repo and how to verify it.
applies_to: Renovate config, the scheduled Action, or dependency-update PR triage.
entrypoint: Read renovate.json, then .github/workflows/renovate.yml.
verification: Confirm the Dependency Dashboard issue and the latest Renovate workflow run.
update_when: The runner, token owner, schedules, grouping, or hash-refresh command changes.
---

# Renovate

This repository self-hosts Renovate through `.github/workflows/renovate.yml`.
It does **not** use the Mend Renovate GitHub App. Do not install that app here;
a second runner would duplicate PRs.

## How it runs

- Schedule: Actions cron `17 10 * * *` (about 05:17 America/Chicago).
- Config schedule: weekday mornings `04:00-08:00` America/Chicago, so the daily
  job is inside the window.
- Auth: repository secret `RENOVATE_TOKEN` (a fine-grained PAT). Pull requests
  and the Dependency Dashboard issue are authored as that token's user
  (`edmundmiller` today), **not** `app/renovate`.
- Hash refresh: `postUpgradeTasks` runs
  `nix run --accept-flake-config .#renovate-update-nix-hashes`.
- Herdr and Hunk release PRs stay manual for
  `.github/workflows/renovate-patch-repair.yml`.

## Expected PR shape

| Branch / group                             | What lands                                          |
| ------------------------------------------ | --------------------------------------------------- |
| `renovate/lock-file-maintenance`           | Monday `flake.lock` refresh (branch automerge)      |
| `renovate/javascript-package-dependencies` | Non-major npm/bun bumps                             |
| `renovate/github-actions`                  | Non-major Actions and digest pins                   |
| `renovate/nix-flake-inputs`                | Versioned flake inputs only                         |
| `renovate/repo-local-nix-package-patches`  | Regex-managed Nix package patches plus hash refresh |
| `renovate/herdr`, `renovate/hunk`          | Overlay/harness + flake tag, no automerge           |
| Major updates                              | Stay on the Dependency Dashboard until checked      |

Unversioned flake pins and private inputs (`agents-workspace`, `tnote`) are not
individual PRs. Bump those with `hey upgrade` when the PAT cannot see the repo.

## Verify

1. Open the Dependency Dashboard issue titled **Dependency Dashboard**.
   It should not list `lookupUpdates error` for the private flake inputs.
2. Actions → **Renovate** → latest `schedule` or `workflow_dispatch` run is
   green, or only fails for an unrelated runner problem.
3. To force a retry: run the workflow manually, or check a box on the
   dashboard (`rebase`, `unlimit`, or create-all rate-limited PRs).
4. A repo-local Nix package PR must rewrite source hashes in the same commit
   as the version bump. If GitHub shows `renovate/artifacts` failed, do not
   merge; rebase from the dashboard after the hash command is fixed.

Live checks: `gh issue list --search 'Dependency Dashboard in:title'` and
`gh run list --workflow=renovate.yml --limit 5`.
