# Worklog: hunk-v0-18-extension-api-v2

Status: verification complete; publication pending

## Objective

Pin the Hunk overlay and package harness to `v0.18.0-beta.0`, make the local patch stack apply and pass its focused checks, and replace patches with extension API v2 implementations only where upstream source proves equivalent behavior. Preserve build-time patches where the API has no complete replacement. Stop when the packaged binary reports the requested version, the retained features pass their focused checks, repository checks pass, and the task branch is published and verified current upstream.

## Decisions

- Keep the existing repository fetch, patch, and extension configuration patterns; add no compatibility framework.
- Classify every checked-in Hunk patch as upstreamed, extension-replaceable, or still build-time-only before editing it.
- Use `GIT_WORK_TREE=$PWD` for Git commands because the shared repository config currently contains an unrelated `core.worktree` override; do not mutate that shared config during this task.
- Extension API v2 can contribute commands, sidebars, file views, transforms, lifecycle handlers, VCS adapters, and dialogs, but cannot alter CLI parsing, switch the active review input, contribute a source-menu item, receive arbitrary review keypresses, or register multi-key leader sequences.
- Preserve all three local features unless a complete API-supported replacement is proven: source switching (patch 1), Space-leader which-key (patch 2), and `hunk resume` CLI state (patch 3).

## Evidence

- `jj root --ignore-working-copy`: current checkout is Git-only.
- `GIT_WORK_TREE=$PWD git status --short --branch`: clean `worktree/quiet-harbor-b625` checkout.
- `overlays/hunk/AGENTS.md`: requires matching `flake.nix` and package-harness refs, `pkg-check hunk`, and `hey check`.
- `nix develop --command pkg-list`: `overlays/hunk` is declared; package metadata currently pins `v0.17.0`.
- Release `v0.18.0-beta.0` resolves to signed commit `e0d175738c09e3f6943e0cc3618184cc89a7d2ce`; a writable upstream workbench exists at `/private/tmp/hunk-v0.18.0-beta.0`.
- All three patches apply cleanly in order at `v0.17.0`; rebasing them to `v0.18.0-beta.0` produces conflicts in patch 1 due to upstream UI and command-registry changes.
- Upstream `docs/extensions.md` and typed API v2 contracts prove no patch has a behaviorally complete extension replacement.
- Rebased and exported all three patches from the target release: source switch `812c039`, command-backed which-key `f286f50`, and resumable-review persistence `5158346`.
- `nix flake lock --update-input hunk`: locked `v0.18.0-beta.0` at `e0d175738c09e3f6943e0cc3618184cc89a7d2ce`.
- `nix develop --command pkg-check hunk`: cloned the tag, applied all three exported patches, passed `bun run typecheck`, and passed all 12 harness test files (322 tests).
- `GIT_WORK_TREE=$PWD hey check`: all Darwin checks passed. Plain `hey check` fails only because the shared `core.worktree` makes treefmt evaluate this checkout as outside its root.
- `darwin-rebuild switch --flake .`: rebuilt `hunkdiff-0.18.0-beta.0` and codesigned `$out/bin/.hunk-wrapped`; activation then stopped at the unrelated Homebrew `vlc` cask API error.
- `hunk --version && hunk resume --help`: reports `0.18.0-beta.0` and the expected resumable-review help text.

## Reviews

`hey agent-review plan` could not run: `Authentication required`; the same agent-review route remains unavailable for landing. An independent code-simplifier review found no behavior-preserving simplification.

## Feedback

- Shared Git config has `core.worktree=/Users/emiller/.codex/worktrees/zele-readonly-guard/dotfiles`; explicit `GIT_WORK_TREE` is required to keep commands scoped to this Herdr checkout.

## Remaining work

- Review the scoped diff, commit the task paths, publish the branch, and verify it is current upstream.

## Commits

This worklog ships with the task commit; publication is verified from repository history.
