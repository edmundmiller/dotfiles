# Worklog: done-active-worktree-cleanup

Status: active

## Objective

Prevent `done` from removing the active Codex or Herdr Git worktree. Completion requires an executable repro to prove the active checkout remains usable, with the existing post-landing cleanup invariant retained for non-active worktrees.

## Decisions

- Treat the Moshi `posix_spawn` error as a consequence of the deleted process CWD unless retesting disproves it. A known-existing `/bin/true` produces the same `ENOENT` when a running Bun process's CWD is deleted.
- Repair the shared `done` skill's Git cleanup contract rather than changing generated Moshi hook code or adding a platform-specific executable fallback.

## Evidence

- `hostname` → `MacTraitor-Pro.local`; `uname -a` confirms Darwin arm64.
- Active-worktree repro: deleting the current Git worktree causes `pwd: .: No such file or directory`.
- Deleted-CWD spawn repro: Bun spawning existing `/bin/true` after its CWD is removed returns `spawn-error:ENOENT:/bin/true`.
- Receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/53e298a49a4b/20260724T035731Z-9e0a912f4224.json`.
- `/run/current-system/sw/bin/moshi-hook --version` → `moshi-hook version 0.2.51`; the configured absolute executable exists.
- `bash skills/catalog/done/scripts/test-verify-workspace-cleanup.sh` passes: Codex- and Herdr-shaped Git worktrees remain accessible after guarded cleanup; a separate safe worktree is removed.

## Reviews

- Plan gate: `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/done-active-worktree-cleanup.md` could not authenticate (`RUNTIME: Authentication required`). Do not retry the unavailable reviewer.
- Local `skill-reviewer` fallback could not start (`No model selected`). Complete the focused script review manually; retain both failures as evidence of unavailable review infrastructure.
- `code-simplifier` reviewed the modified skill and scripts. Applied its high-value test readability refinement; no simplification was warranted in the verifier or duplicated Git/jj rules.

## Feedback

- `done` says cleanup is last but does not explicitly preserve the agent-hosting worktree. This permits launcher-owned Codex/Herdr worktrees to be deleted before their returning shell/session stops.

## Remaining work

- Commit the strict expected-failure regression test and its green implementation separately.
- Run focused skill validation, host activation, runtime smoke, landing gate, and publish.

## Commits

- Pending.
