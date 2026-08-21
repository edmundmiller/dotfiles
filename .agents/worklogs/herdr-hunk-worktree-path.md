---
purpose: Track the Herdr Hunk worktree path correction.
applies_to: The dotfiles.dev-layout Herdr plugin path selection behavior.
entrypoint: packages/herdr-plugins/dotfiles-dev-layout/dev_layout.py
verification: Run the plugin tests, packaging contracts, and repository landing gates.
update_when: Herdr bootstrap or Hunk checkout selection changes.
---

# Worklog: herdr-hunk-worktree-path

Status: complete

## Objective

Make Herdr dev-layout bootstrap and manual Hunk actions open against the focused
pane's active Git worktree instead of stale dotfiles workspace metadata. Stop
when focused and full repository checks pass, the change is committed and
published to `origin/main`, remote equality is proved, and the thread is
archived.

## Decisions

- Treat Herdr 0.8.1 `focused_pane_cwd` as the live working directory and prefer
  it over independent worktree/workspace metadata.
- Keep OMP at the focused pane's raw CWD while resolving Hunk to the first valid
  Git root from focused pane, worktree checkout/path, workspace, then process
  CWD.
- Skip deleted directory candidates without hiding a missing Git executable.

## Evidence

- Red/green focused regression run failed in both path-selection scenarios
  before implementation, then passed 26 plugin tests.
- Fifteen Herdr packaging contract tests passed by direct function invocation;
  this orb does not provide pytest outside the repository's Nix agent shell.
- `python3 -m py_compile` and `git diff --check` passed.
- `npx calldiff@latest` 0.5.0 confirmed bootstrap and manual Hunk now share the
  intended checkout resolver without changing downstream tab/pane behavior.
- `hey check --worktree` exercised the full repository gate. It reached the
  changed Herdr package and then failed on unrelated baseline inputs: pinned
  `agents-workspace` and `tnote` GitHub archive revisions return HTTP 404, and
  a Darwin-only derivation cannot build on this x86_64-linux orb. This checkout
  started exactly at `origin/main`; the change does not touch either flake input
  or platform check.
- `hey agent-audit-tests` passed `test-confidence`.
- `hey agent-finish` passed worklog, rules, skill quality, test-confidence, and
  inventory checks. Its aggregate gates retained unrelated orb failures: the
  subprocess running repo-quality lost the checkout path, and OMP rule tests
  could not find the host-only `omp` executable.

## Reviews

- Oracle found that bootstrap lacked manual Hunk's fallback chain and that
  deleted candidate directories could abort resolution. Both findings are
  covered by regressions and resolved in the current diff.

## Feedback

None.

## Remaining work

- None. Live Herdr 0.8.1 smoke testing remains host-only because this Linux orb
  does not run the user's macOS Herdr session.

## Commits

- Final landing commit: `fix(herdr): open Hunk in focused worktree`.
