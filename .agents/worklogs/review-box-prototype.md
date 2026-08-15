# Worklog: review-box-prototype

Status: complete

## Objective

Ship `dotfiles-esav.7`: promote a ghui pull request into a resumable four-tab Herdr Review Box through one shared pi-herdr decision flow, with Nix-managed CLI and configuration. Stop after validation, bead closeout, landing to `origin/main`, and tag `agent-work/review-box-prototype`.

## Decisions

- pi-herdr owns the manifest, lock, worktree, and create/resume/restore/refresh decision flow. The CLI and ghui patch remain thin adapters.
- Cross-package TypeScript imports use the Bun workspace package name; no relative package-boundary import or compatibility shim remains.
- ghui carries one patch against its pinned upstream revision and invokes the configured bridge executable with PR JSON on stdin.
- The package creates a temporary workspace symlink for `pi-herdr` before `bun build --compile`; the installed binary is self-contained and ad-hoc signed on Darwin.
- Activation was deferred from the dev-layout fix to the packaging feature because the mission boundary authorized `hey re` only there.
- The optional kill-9 atomicity test was not added: atomic temp-plus-rename behavior is covered without introducing a flaky process-termination test.

## Evidence

- `bun test && bun run typecheck` in pi-herdr: 34 tests passed; typecheck passed.
- `bun test && bun run typecheck` in pi-review-box: 75 tests passed; typecheck passed.
- `./bin/qa-changed`: pi-herdr and pi-review-box checks executed; package integration tests passed.
- `pkg-check ghui`: fresh pinned source patched, typechecked, and tested successfully.
- `nix build '.#darwinConfigurations."MacTraitor-Pro".pkgs.my.ghui'`: built; packaged ghui reported 0.7.1.
- `pkg-check review-box`: compiled, signed, and ran `review-box --help` from a clean clone.
- `nix build '.#darwinConfigurations."MacTraitor-Pro".pkgs.my.review-box'`: built; `result/bin/review-box --help` passed.
- `hey check`: Darwin evaluation, formatting, hooks, package harness, policy, and ast-grep checks passed.
- `hey re`: activation succeeded. Live ghui and Review Box configs retained theme keys, pointed to an executable bridge, and mapped `edmundmiller/dotfiles` to `/Users/emiller/.config/dotfiles`.
- First amended VAL-BRIDGE-003 run found a fifth initial Herdr tab. After the regression fix and activation, the serialized validator passed: workspace `w4D` had the 56-character PR label, matching worktree cwd, final focus, and exactly Hunk, Critique, OMP Review, and Approve in order. Cleanup restored the baseline workspace IDs and focus with no PR #216 artifacts remaining.
- `bun test ./tests/*.test.ts --timeout 30000`: all 91 package integration tests passed after making the temporary context repository carry its own Git identity, matching Linux CI.
- Landing verification matched local and remote `main` at `da88bc67b4c33ae0ace1d67df569ab9e3aa8dc85`; `agent-work/review-box-prototype` was pushed and `dotfiles-esav.7` was closed.

## Reviews

- Bridge-core scrutiny passed after the workspace-import correction.
- A targeted code-simplifier review covered the shared module and initial-tab cleanup.
- Landing review passed after rebasing onto current `origin/main`; the follow-up Linux fixture correction passed the full package integration suite.

## Feedback

- Herdr 0.8.0 plugin hooks expose label/cwd/worktree context but not workspace `--env`; Review Box bootstrap exclusion must use those observable fields.
- A newly created Herdr workspace owns an initial tab independently of plugin bootstrap. Callers requiring an exact tab set must explicitly replace it.

## Remaining work

- None.

## Commits

- `6f66876bb` extract PR-review orchestration
- `a35070b7d` extract shared decision flow
- `40a2daf96` add bridge CLI
- `b4060a979` use workspace package import
- `507909072` parse Herdr envelopes
- `75d939253` skip generic dev-layout bootstrap
- `d1eabb30b` harden manifest and lock tests
- `b3a6a59f0` clean shared imports
- `2a74915db` document workspace imports
- `4c2753065` add ghui promotion action
- `99cb6512f` package and configure bridge
- `ddc6200c0` remove the initial Review Box tab
- `ea42fbb93` add usage and implementation documentation
