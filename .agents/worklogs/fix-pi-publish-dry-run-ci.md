# Worklog: fix-pi-publish-dry-run-ci

Status: complete

## Objective

Make the Pi package publication workflow use the repository's Bun workspace
lockfile and provide a repeatable remote dry-run that validates the package
without publishing it.

## Decisions

- Keep this follow-up separate from the landed Pi Hunk and QA-runtime fixes.
- Install the workspace with Bun because `packages/pi-packages/bun.lock` is the
  authoritative lockfile and one workspace dependency uses `workspace:*`.
- Use an unauthenticated `npm pack --dry-run` step for the explicit dry-run
  branch. An actual release remains a separate authenticated
  `npm publish --access public` step.
- Do not publish or bump a package version to validate this repair.

## Evidence

- GitHub dry-run `33296333576` passed detection and Pi Hunk QA, then failed
  before publication because `npm install` rejected `pi-herdr: workspace:*`
  with `EUNSUPPORTEDPROTOCOL`.
- A clean clone installed the workspace with
  `bun install --frozen-lockfile --ignore-scripts`.
- In that clone, `npm publish --dry-run` rejected the already-published
  `pi-hunk@0.1.0`, while `npm pack --dry-run` successfully validated the same
  five-file package without creating or publishing a tarball.
- `actionlint .github/workflows/publish-packages.yml` and `git diff --check`
  pass.
- `hey check --worktree` passes Darwin evaluation, formatting, hooks, tmux,
  package harness/policy, DJI Mic Mini, and ast-grep checks.
- GitHub workflow-dispatch run `33296773257` passed at
  `b350d33243d915cb9d846e19acfbd25bae9e27ee`: detection selected `pi-hunk`,
  package QA passed, Bun installed the locked workspace, and
  `npm pack --dry-run` validated the five-file package.
- In that remote run, `Validate package (dry run)` passed and the authenticated
  `Publish` step was explicitly skipped, so no package was published.

## Reviews

- The failed remote job log and current workspace lockfile were read before
  editing.
- Independent final review found no issues and confirmed typed boolean input
  routing, unauthenticated dry-run validation, authenticated push publication,
  and Bun setup ordering.

## Feedback

- A safe release dry-run must be repeatable against the current version; npm's
  publish dry-run still consults the registry and can reject an existing
  version.

## Remaining work

None.

## Commits

- `b350d33243d915cb9d846e19acfbd25bae9e27ee` — workflow repair and local
  evidence.
- Annotated tag `agent-work/fix-pi-publish-dry-run-ci` is created after final
  closeout lands.
