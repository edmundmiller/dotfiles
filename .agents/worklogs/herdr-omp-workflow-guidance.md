# Worklog: herdr-omp-workflow-guidance

Status: complete

## Objective

Make shared agent rules and Herdr/jj skills match the live, verified workflow: Herdr creates task workspaces, OMP is the default agent tab, Hunk opens only for Git checkouts, and existing Herdr-created jj workspaces are recorded without creating a second workspace. Stop when focused agent/skill checks pass, runtime guidance has no stale Codex bootstrap claims, changes are reviewed, committed, published, and proven current upstream.

## Decisions

- Keep Herdr runtime topology in the existing version-control rule and workflow skills instead of adding another overlapping rule.
- Preserve Codex-specific Git worktree boundary guidance; only replace stale claims that Codex is Herdr's default task agent.
- Treat Herdr IDs as live handles and task names as durable names.

## Evidence

- Host: `MacTraitor-Pro.local`; Darwin arm64.
- Backend: Git; `jj root --ignore-working-copy` reported no jj repository.
- Existing unrelated changes: `flake.nix` and `hosts/nuc/*`; left unstaged and outside the scoped diff.
- Live Herdr bootstrap was previously smoke-tested: non-Git workspace created only OMP; Git checkout created OMP plus Hunk with OMP focused.
- `python3 -m unittest tests/test_agent_response_contract.py tests/test_agent_quality.py`: 22 tests passed after the final rule/test edits.
- `python3 bin/agent-quality inventory --check`: passed.
- `bun run test` in `tests/skill-evals`: 4 tests passed after the final edits.
- `hey agent-audit-tests`: passed.
- OMP condition smoke check matched `agent-start`, Herdr, Hunk, jj, and selected Git mutations while excluding `git status`.
- Stale-bootstrap grep found no Codex-focused or mandatory two-tab claims in the scoped guidance.
- `hey check --worktree` passed Darwin evaluation, pre-commit, tmux, package, and ast-grep checks; its formatting check failed only after modifying pre-existing unrelated NUC changes.
- Full `darwin-rebuild switch` built the configuration but failed late in unrelated Homebrew cask evaluation for VLC.
- The final Home Manager generation built and linked the agent files; activation then failed late in an unrelated missing `bin/macos-wallpaper-placement.py` step.
- Live reads confirmed the new shared rule, OMP conditional rule, and Herdr/jj skill under `~/.pi`, `~/.omp`, and `~/.agents`.

## Reviews

- Plan review: required Claude reviewer failed authentication; one Gemini fallback failed because the installed CLI lacks ACP support. Both failures are recorded; no review result was fabricated.
- Skill review: failed initially on missing pure-jj guidance, trigger phrasing, bookmark terminology, and a malformed Finish section; all findings were fixed. Final re-review passed with no actionable findings.
- Landing review: passed after updating the stale response-contract test, adding behavioral coverage for the OMP condition, restoring the rule's stable name, and matching `HERDR_ENV=1` at the nested-Herdr decision point.

## Feedback

- Herdr-created jj workspaces need `hey agent-start` without `--workspace`; creating another workspace breaks the one-task/one-workspace contract.
- Hunk is not a universal jj review surface. Pure jj must use `jj diff --git -r @` in OMP and preserve findings in the worklog or final handoff.
- `hey check --worktree` can format unrelated dirty files before reporting `--fail-on-change`; use a scoped clean checkout when unrelated Nix changes are present.
- `hey agent-audit-tests` did not cover `tests/test_agent_response_contract.py`; the version-control rule changed behavior without updating its contract test. Run the full unittest suite when shared rules change.

## Remaining work

None.

## Commits

- `docs(herdr): align agent workflow with OMP bootstrap`
