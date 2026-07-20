# Worklog: jj-agent-flywheel

Status: active

## Objective

Make jj the deterministic agent VCS path: start runs with backend-aware receipts, block Git mutations inside jj workspaces, land and verify jj changes against the remote, and aggregate completion evidence into improvement signals. Stop when focused tests, quality gates, deployment, and upstream landing are proved.

## Decisions

- Preserve Git as a supported backend; select jj only from live repository state.
- Never initialize jj inside a Codex-managed Git worktree. Return an actionable boundary instead.
- Store run receipts outside repositories by default so landing and cleanup cannot erase evidence.
- Store versioned JSON receipts under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-agent-runs/`; retain them until an explicit sweep/prune policy is added.
- Receipt v1 records run/task identity, runtime/model, repository/workspace, backend, starting VCS IDs, status, landing proof, retries, corrections, timestamps, and errors.
- Extend the single global `done` skill with Git/JJ backend branches; do not create a parallel skill.
- Bound sweeps by age or count and aggregate only receipt v1 fields.
- Keep raw publish tools guarded; the `done` workflow is the normal authorized publication path.
- Preserve the unrelated untracked `.agents/skills/homebox/` directory.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Baseline branch created from detached `origin/main`: `codex/jj-agent-flywheel`.
- Baseline unrelated dirt: `.agents/skills/homebox/` only.
- Dogfood receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/5443160216c0/20260720T004955Z-e5690f5c721a.json`; correctly detected the Codex Git-worktree boundary.
- RED: Python tests failed for absent `start`, `complete`, sweep aggregation, and JJ verifier; policy test still allowed mutation paths.
- GREEN: `python3 -m unittest tests.test_agent_quality tests.test_done_skill` passes 16 tests, including a real colocated JJ repository, isolated workspace, sign-on-push rewrite, authoritative bare remote, and Git-worktree refusal.
- GREEN: `bun test pi-command-policy-bridge/index.test.ts` passes 10 tests / 41 assertions; package typecheck passes.
- GREEN: Ruff, ShellCheck, Nu source check, `git diff --check`, and `hey check` pass.
- Weekly receipt sweep is declared for Monday 09:15 via launchd.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` built and deployed. First activation hit a transient nix-daemon restart race; daemon health passed and one retry completed.
- `launchctl print gui/502/org.nixos.agent-quality-sweep` proves the loaded Monday 09:15 trigger and packaged command.
- `hey agent-audit-tests` and `hey agent-finish --worklog .agents/worklogs/jj-agent-flywheel.md` pass; visual and zsh checks are correctly not applicable.

## Reviews

- Plan review: OpenCode (different family) passed after Claude authentication failed. Resolved findings by pinning receipt schema/path, choosing one backend-branching `done` skill, adding real temporary JJ workspace/remote tests, and keeping the implementation as direct backend detection rather than a VCS framework. Raw `git push` remains blocked in JJ workspaces because verified publication belongs to `done`.
- Landing review: OpenCode (different family) passed all dimensions. Resolved its only cosmetic finding by removing the duplicate pending entry; no code findings.

## Feedback

- Existing jj guidance conflates workspace-local `@` with repository-shared state and recommends operation-wide recovery too casually.
- Existing `done` skill proves only Git landing despite globally installed jj support.
- Existing sweep reads commit prose instead of durable run evidence.

## Remaining work

- Reconcile with current upstream, land on `main`, rebuild from the primary checkout, verify remote equality, complete receipt, and tag.

## Commits

- `2993b6c01` test(agents): capture assertTrue audit false positive
- `b096382cc` fix(agents): distinguish assertTrue from vacuous assertions
- `6fd863dc9` feat(agents): add backend-aware run receipts
- `a199d6103` feat(pi): block Git mutations inside jj repositories
- `7f0f401b6` feat(skills): land and verify jj workspaces
