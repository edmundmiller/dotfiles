# Worklog: done-active-worktree-cleanup

Status: blocked

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
- `hey check` passes all Darwin checks: child-lock sync, configuration evaluation, formatting, pre-commit, tmux, package harness/policy, and ast-grep.
- `hey re` succeeds after preserving stale `~/.config/gh/config.yml.bkup` as `config.yml.bkup.pre-20260724`; deployed `~/.agents/skills/done` runs the same Codex/Herdr smoke test.
- `flake.nix` now declares the nested skills catalog as `path:./skills`; regenerated `flake.lock` pins its `narHash`, resolving the prior unlocked-local-input check failure.

## Reviews

- Plan gate: `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/done-active-worktree-cleanup.md` could not authenticate (`RUNTIME: Authentication required`). Do not retry the unavailable reviewer.
- Local `skill-reviewer` fallback could not start (`No model selected`). Complete the focused script review manually; retain both failures as evidence of unavailable review infrastructure.
- `code-simplifier` reviewed the modified skill and scripts. Applied its high-value test readability refinement; no simplification was warranted in the verifier or duplicated Git/jj rules.

## Feedback

- `done` says cleanup is last but does not explicitly preserve the agent-hosting worktree. This permits launcher-owned Codex/Herdr worktrees to be deleted before their returning shell/session stops.

## Remaining work

- `hey agent-finish` is blocked by unrelated agent-quality infrastructure: its Nix-store test process fails `jj git init --colocate` in a fresh temporary Git repo, though the same command passes directly on this host. It also runs `git diff --cached` outside a Git checkout. The `done` skill test, Darwin checks, and activation all pass.

## Commits

- `d9bb74f73 test(done): cover active worktree cleanup`
- `fd3d51f02 fix(done): preserve active launcher worktrees`
- `1436bd325 fix(nix): lock local skills catalog`
