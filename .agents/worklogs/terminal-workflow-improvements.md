# Worklog: terminal-workflow-improvements

Status: complete

## Objective

Align the active macOS terminal stack with Herdr and add a minimal Neovim
distraction-free writing mode. Keep Raycast as the macOS workspace owner. Stop
when focused configuration checks and the repository landing gate pass, or when
an exact environment blocker is recorded.

## Decisions

- Keep Ghostty's shared tmux bindings for tmux hosts, but override them on the
  Herdr-enabled Mac instead of changing unrelated Linux behavior.
- Keep the existing Raycast workspace workflow; do not deploy AeroSpace.
- Add one established Zen mode plugin without prose tooling or database plugins.

## Evidence

- Targeted checks verified the generated Ghostty override order and preserved
  the shared tmux bindings for other hosts: PASS.
- Headless Neovim opened Zen mode and measured its configured 90-column width:
  PASS.
- `python3 bin/agent-quality audit-tests ...`: `PASS test-confidence`.
- `python3 -m unittest discover -s tests -p 'test_agent_quality.py'`: 24 tests
  passed with one intentional skip.
- Full `hey check --worktree` was attempted before landing and stopped while
  evaluating the pre-existing `tnote` package because its pinned GitHub archive
  returns HTTP 404. The failure occurs before this task's files are evaluated.
- Full Mac system evaluation cannot run in this x86_64 Linux orb because an
  aarch64-darwin Herdr source derivation is required during evaluation. The
  target Mac must run `hey re` for activation-level verification.
- `agent-quality finish` reached the repository-wide `hey check --worktree`,
  which reported unrelated failures in `tnote`, Home Assistant assertions, and
  NUC checks, then stalled as in the prior orb thread. It was terminated after
  four minutes; focused checks above remain green.

## Reviews

- No cross-model review requested.

## Feedback

- `.agents/setup` sees the Nix binary but cannot expose it when the inherited
  `__ETC_PROFILE_NIX_SOURCED` marker is set while Nix is absent from `PATH`.
- `nix develop .#default` attempts to install repository hooks and rejects the
  orb's global `core.hooksPath`; direct formatter invocations were required.
- The broad quality manifest runs the full cross-host flake for Mac-only config
  changes, reproducing the expensive unrelated-check failure from the prior orb.

## Remaining work

- Activation-level verification remains: run `hey re` on MacTraitor-Pro, then
  restart Ghostty once because it caches keybindings.

## Commits

- This landing commit contains the Herdr navigation and Neovim Zen mode changes.
