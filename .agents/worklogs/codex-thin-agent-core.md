---
purpose: Record the Codex thin-core migration and live verification.
applies_to: Codex startup rules, selective skills, OMP wiring, and activation fixes.
entrypoint: Review the outcome, evidence, side effects, and publication boundary below.
verification: Run the exact unittest suite, hey check, hey re, and live agent readbacks.
update_when: The migration evidence, runtime boundary, or live activation state changes.
---

# Worklog: Codex thin agent core

Status: complete

## Objective

Codex no longer receives the 2,833-word legacy shared-rule bundle at startup.
Its managed global `AGENTS.md` is the 212-word thin core. Procedures remain
available through task-selected skills, repository routers, nested
`AGENTS.md` files, role profiles, and deterministic hooks.

## Decisions

This pilot intentionally leaves the legacy bundle in place for Claude, Pi, and
OpenCode until each runtime has an equivalent selective-loading review. OMP
continues to use the thin core and its conditional TTSR rules.

## Implemented

- Wired Codex to `config/agents/core.md` with a tested 220-word maximum.
- Removed procedural and worker-lane duplication from the Codex bootstrap while
  preserving those contracts in their owning skills, profiles, and routers.
- Protected both global startup-rule surfaces from OMP session introspection.
- Kept the generated agent-quality inventory, pre-commit checks, Nix checks, and
  completion hook aligned with the new instruction boundary.
- Reconciled OMP against the overlaid 18.0.3 runtime: setup version 2, rail
  composer, `[remote, soft]` compaction order, and smart unexpected-stop
  detection.
- Added Darwin activation regressions for Claude cleanup, Home Manager Bash
  compatibility, Hermes launcher/PID behavior, the `done` cleanup helper, and
  generated skill-bundle realization.
- Fixed activation blockers without disabling tests: scoped Hermes ctypes
  linkage, the upstream tokenizers cc-rs deadlock patch, Bash 3.2 launcher
  compatibility, Bash 5.3 heredoc compatibility, and both Hermes gateway PID
  formats.

## Evidence

- Exact regression suite: 207 passed, 16 skipped.
- `hey check --worktree`: all Darwin checks passed across 38 changed files.
- Full system build and `AGENT=1 hey re`: completed successfully.
- Active system: `/nix/store/77zk2pf11c3fkc099lzj07mzck6pf58b-darwin-system-26.11.d5bd9cd`.
- Live Codex core: 212 words, SHA-256
  `8f2ee243d67fcea61fa518a5cb1556567c7bbfdfeb2f8d794d4c1bd8874cc717`,
  byte-identical to `config/agents/core.md`.
- MacTraitor-Pro and Seqeratop generate the same byte-identical core at
  `/nix/store/ayjpawnhmcwybvsxpbac1qyk5ssm4s1l-hm_.codexAGENTS.md`.
- A fresh ephemeral Codex session loaded the installed `done` skill, returned
  `SKILL_LOADED=true` and `STARTUP_RULES_WORDS=212`, then completed the live
  Stop hook.
- Live OMP 18.0.3 reports setup 2, `composer.shape=rail`,
  `compaction.methodOrder=[remote, soft]`, and
  `features.unexpectedStopDetection=smart`.
- `hey hermes-local --smoke-only` passed authenticated ChatGPT login, exact
  agents-workspace revision `c16051f230767695d15b0f6bd78a247d128539f4`,
  profiles `amosburton,orchestrator`, gateway supervision, and dispatcher
  health. Gateway PID 38696 was independently read back.
- The patched h5py suite passed 798 tests with 24 skips; tokenizers passed 134
  tests with 1 skip and 52 deselections. Hermes 0.20.5 wrappers, ctypes callback,
  linkage, and version smokes passed.

## Reviews

Independent audits found no critical or high-severity issues. The remaining
review request—durably selecting the new activation regressions—was resolved by
adding them to `.agents/quality.json`; the completion hook also discovers the
entire `tests/test_*.py` suite.

## Feedback

- Keep universal prompt invariants small; route procedures to skills and the
  nearest repository document.
- Test prompt contracts at their owning surface instead of copying selective
  workflow vocabulary back into startup context.
- Prove generated and live agent state independently; successful evaluation or
  activation output alone is not authoritative readback.

## Activation side effects

- Moshi's first-run setup created
  `~/.config/opencode2/moshi/config.toml` with both default features enabled.
- Home Manager performed the intended one-time migration of
  `~/.codex/config.toml` from a stale managed symlink to a writable regular
  file. Its app-managed content was preserved; cleanup simulation showed no
  further rewrite.
- A stale, ownerless primary-checkout `.git/index.lock` was moved recoverably
  to `/tmp/dotfiles-index.lock.stale-20260827T2012`.
- Unrelated primary-checkout changes were preserved.

## Remaining work

No further work remains within the requested local-only scope. Publication is
intentionally still outside that scope:

No commit, push, merge, or PR was requested or performed. The activation source
is the current-origin detached worktree
`/Users/emiller/.config/dotfiles.codex-thin-final` at
`25592d95ca903bf989e60726078fd44ac14e8cdf`. The primary checkout contains the
same task edits where compatible, while retaining its unrelated dirty work and
older OMP-base semantics.

Run receipt:
`/Users/emiller/.local/state/dotfiles-agent-runs/53e298a49a4b/20260827T174152Z-288fd6ec38fa.json`.

## Commits

None; commit, push, merge, and PR creation were not requested or performed.
