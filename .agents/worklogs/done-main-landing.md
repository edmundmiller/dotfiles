# Worklog: done-main-landing

Status: complete

## Objective

Make the global `done` skill land each finished worktree on the repository's actual default branch, publish when a remote exists, verify ancestry and remote equality, and clean up only after proof. Stop when the catalog source is deployed, focused tests pass, and `origin/main` contains the change.

## Decisions

- Replace the remote `bholmesdev/done` selection with a checkout-owned catalog skill so every repo receives one durable contract.
- Default bare `done` invocations to direct default-branch landing. Preserve explicit PR, local-only, no-push, and repository-policy overrides.
- Treat commit, integration, publication, and cleanup as separate proven states.
- Never force-remove a worktree containing untracked or unrelated files.

## Evidence

- Reviewed 24 old Codex task logs across dotfiles, Obsidian vault, mill-docs,
  and finances.
- Recurring failure: feature rebased but `main` not updated; local `main` updated but not pushed; worktree removed before publication proof.
- Successful pattern: fast-forward destination, push destination, verify destination equals remote and contains feature tip, then delete branch/worktree.
- `python3 tests/test_done_skill.py`: 2 passed, including a temporary bare
  remote/worktree regression.
- `nix flake check ./skills`: passed.
- Darwin rebuild: first activation hit a Nix-daemon restart race; daemon probe
  passed and the immediate retry completed.
- Live `~/.agents/skills/done` source and executable verifier match the catalog.
- Post-review Darwin rebuild and live-source comparison passed.
- `hey check`: all Darwin checks passed.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey agent-finish --worklog ...`: all applicable Darwin, repository,
  inventory, worklog, and test-confidence gates passed.
- `br sync --flush-only`: nothing to export.
- Bundled verifier: integration tip `c323db5d6` is on `main`; local `main` and
  `origin/main` both resolved to `c323db5d6` after publication.
- Unrelated NUC test and Homebox/Betty files remained unstaged.

## Reviews

- Plan review: OpenCode heterogeneous reviewer passed. It confirmed the missing
  catalog source and remote selection are the intended red state; requested a
  behavioral landing check beyond phrase matching.
- Landing review: OpenCode passed correctness, security, maintainability, and
  test confidence. Initial gate blocked only on recording the review here.
  Applied its canonical installed-script path and fallback-command consistency
  findings. The noted remote race is inherent after any read; local/remote
  equality already makes the ancestor proof transitive at the observed tips.
- Landing review rerun: passed all code gates; stale hash, active status,
  publication, and tag were the only closeout findings and are resolved here.

## Feedback

- Upstream skill says to rebase and ask for a disposition, but lacks an end-to-end landing invariant.

## Remaining work

None.

## Commits

- `747a38be9` — expected-failure landing contract after rebase.
- `c323db5d6` — catalog skill, verifier, remote-source removal, green tests after rebase.
