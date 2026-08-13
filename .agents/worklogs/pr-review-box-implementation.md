# Worklog: pr-review-box-implementation

Status: complete

## Objective

Deliver a working Pi/OMP command that creates or resumes one isolated Herdr Review Box per GitHub pull request, with Hunk, agent-review, and human-submit tabs. Stop when repeated invocation is exercised by tests, the extension loads in the installed Pi runtime, and the change is landed and verified upstream.

## Decisions

- Extend the existing `pi-herdr` public extension surface; do not patch Pi core or create a second launcher.
- Treat GitHub review submission as human-only. The approval tab prints commands but never executes them.
- Persist only reconstructable Review Box identity and head metadata; GitHub remains the pull-request source of truth.

## Evidence

- Pi 0.84.1 exposes `registerTool` and `registerCommand`; official extension docs confirm both are supported public APIs.
- Existing `herdr_pr_review_workspace` already creates the worktree, Herdr workspace, Hunk tab, OMP review tab, and approval tab.
- `bun test extensions/herdr.test.ts`: 5 tests passed, including create, resume, and new-head refresh without a duplicate worktree.
- `bun run check`: TypeScript passed.
- `python3 -m unittest dev_layout_test.py`: 15 tests passed, including Review Box ownership of its tabs.
- Isolated Pi RPC `get_commands`: discovered `/review-box` from the edited extension without invoking a model.
- Direct Nix evaluation: local `pi-herdr` replaced the legacy npm source in generated Pi settings.
- `bun test ./tests/omp-plugin-extension-packaging.test.ts`: passed.
- `nixfmt --check` and scoped `oxfmt --check`: passed.
- `hey check`: all Darwin checks passed, including configuration evaluation, package policy, and ast-grep tests.

## Reviews

- Self-review corrected duplicate generic Herdr tabs by adding the explicit `HERDR_REVIEW_BOX=1` ownership boundary.
- Self-review corrected head refresh to rebuild Hunk, Critique, and agent tabs rather than leaving the prior pass running.

## Feedback

- The prior Wayfinder map stopped after one lifecycle decision even though the original request authorized implementation.
- `modules/agents/pi/test-settings-json.sh` imports ambient user nixpkgs overlays and can fail before its own assertions; the direct isolated settings evaluation and full `hey check` both passed.

## Remaining work

None.

## Commits

- `feat(review): add resumable Herdr Review Boxes`
