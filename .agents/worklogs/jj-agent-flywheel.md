# Worklog: jj-agent-flywheel

Status: complete

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
- Rebased cleanly onto `origin/main` at `cf69f19191`; focused Python/Bun tests and typecheck pass after rebase.
- `br sync --flush-only` exported no changes. `git push --dry-run origin HEAD:main` proves a fast-forward landing.
- Primary checkout `/Users/emiller/.config/dotfiles` contains an unrelated local commit and dirty Herdr/model-routing work. It remains untouched; authoritative `origin/main` will be landed from this clean worktree.
- Follow-up deployment fix packages `agent-quality` and the Pi policy bridge in Nix, removing runtime dependence on the occupied primary checkout.
- Live smoke: packaged `agent-quality inventory --check` passes; `hey agent-sweep` works from `/tmp`; Pi settings and package symlink resolve under `~/.pi/agent`; launchd points at the packaged command.
- Receipt `20260720T004955Z-e5690f5c721a` is complete with local/remote equality, one recorded deployment retry, zero corrections, and no false-done/errors in the sweep.

## Reviews

- Plan review: OpenCode (different family) passed after Claude authentication failed. Resolved findings by pinning receipt schema/path, choosing one backend-branching `done` skill, adding real temporary JJ workspace/remote tests, and keeping the implementation as direct backend detection rather than a VCS framework. Raw `git push` remains blocked in JJ workspaces because verified publication belongs to `done`.
- Landing review: OpenCode (different family) passed all dimensions. Resolved its only cosmetic finding by removing the duplicate pending entry; no code findings.

## Feedback

- Existing jj guidance conflates workspace-local `@` with repository-shared state and recommends operation-wide recovery too casually.
- Existing `done` skill proves only Git landing despite globally installed jj support.
- Existing sweep reads commit prose instead of durable run evidence.

## Remaining work

- None.

## Commits

- `483f46cf8` test(agents): capture assertTrue audit false positive
- `934c7b547` fix(agents): distinguish assertTrue from vacuous assertions
- `67d0b3f9e` feat(agents): add backend-aware run receipts
- `5dacc969d` feat(pi): block Git mutations inside jj repositories
- `bee03949f` feat(skills): land and verify jj workspaces
- `1960897de` docs(agents): record jj flywheel evidence
- `4ce9d89df` docs(agents): record jj landing boundary
- `10d322f23` fix(agents): deploy jj workflow tools from Nix
- Final worklog completion commit follows this record.
