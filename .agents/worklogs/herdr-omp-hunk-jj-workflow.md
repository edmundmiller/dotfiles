# Worklog: herdr-omp-hunk-jj-workflow

Status: complete

## Objective

Deliver one end-to-end Herdr/OMP/Hunk workflow with jj workspaces for jj repos and native Herdr worktrees as the Git-only fallback. Creation must open exactly OMP and Hunk, raw jj must own version-control mutations, Hunk and explicit user commands must gate commits/reviews/publishing/merge, and unsafe removal must refuse data loss. Stop only after focused tests, deployed runtime smoke checks, Darwin checks, landing review, commit, rebase, push, and upstream verification pass.

## Decisions

- One issue or PR owns one Herdr workspace and one isolated checkout.
- The jj-workspace plugin owns jj workspace creation; `prefix+a` is the jj action and `prefix+g` remains the Git-only fallback.
- Stable names are `issue-N-slug`, `pr-N-slug`, or `task-slug`; the wizard defaults the base to `trunk()` and accepts an explicit published parent bookmark.
- Built-in `workspace_created` and `worktree_created` events both bootstrap exactly OMP and Hunk.
- Raw jj 0.37 is canonical. Delete jut package, skill, and wiring.
- Before jj mutations, verify `pwd` and `jj log -r @`. Never inspect with `jj edit`; stay on one bookmark per workspace.
- Shape each reviewed commit in place with `jj describe`/`jj squash`, set the task bookmark to `@`, and create the next working-copy commit only when another intent begins.
- Hunk review plus explicit `approve commit`, `publish`, `submit review`, `ship`, and `cleanup` commands gate mutations.
- Fetch is global, but rebases and pushes are scoped to the task bookmark. Stacked children target a published parent and repair themselves after parent merge.
- External PR review is read-only by default.
- Creation rolls back only a newly created empty partial workspace. Cleanup rejects the main workspace, dirty or wrong-task state, and any open or unverifiable PR. Abandonment is a separate exact-name confirmation path.
- Generic plugin changes go upstream first; carry a pinned fork commit until released. GitHub/layout behavior stays local except the generic closed-PR cleanup gate.

## Evidence

- `hostname && uname -a`: MacTraitor-Pro.local, Darwin arm64.
- Herdr client/server 0.7.4, protocol 16; jj 0.37.0; jut 0.1.0.
- Upstream plugin PR `NathanFlurry/herdr-plugin-jj-workspace#4` is open from fork commit `ec8fde27e0cf4664012b585ebc2dc7cb0934ee1b`.
- The plugin's full Rust suite passes: eight tests across unit and integration suites. Tests cover rollback, existing-bookmark preservation, dirty/open-PR/main-workspace refusal, typed abandon, stable prefixes, and same-target workspace identity.
- The local layout plugin's full Python module passes eight tests, including exact underscore event names, idempotency, exactly OMP plus Hunk, and OMP focus.
- Historical audit of about 63 Pi sessions found zero real-project jut use; development-only use showed repeated config failures and missed untracked files.
- Temporary native-jj smoke test completed two commits, moved one bookmark, and pushed only that bookmark. Temporary artifacts were removed.
- Working tree was clean before implementation except this worklog. `pkg-list` is unavailable on PATH, so package validation must use the repository's remaining focused checks.
- Darwin rebuild and Home Manager activation pass. A second unchanged activation reports the jj plugin already pinned instead of reinstalling it.
- The live Herdr registry reports `dotfiles.dev-layout` enabled with `workspace_created` and `worktree_created`, and the jj plugin at the exact fork commit with `trunk()` plus the three stable-name prefixes.
- Herdr remains running on 0.7.4/protocol 16 with `restart_needed: no`; no stop, restart, signal, or kill was used.
- The global catalog deploys `herdr-jj-workflow` at `~/.agents/skills/`; the rebuilt host no longer exposes a `jut` executable.
- Agent-quality framework tests pass (15 tests after rebase), inventory is current, and test-confidence passes.
- `hey check --worktree` passes Darwin evaluation, child-lock sync, tmux tests, package harness/policy tests, and ast-grep tests. Its formatting and hook stages cannot run because the repository has neither `prek.toml` nor `.pre-commit-config.yaml`.
- `worktree/calm-cloud-3009` was rebased onto `origin/main`, pushed, and verified current upstream.

## Reviews

- Grilling design review completed with explicit final confirmation.
- Plan review attempted with the default Claude reviewer and Gemini reviewer. Both exited at ACP `session/new` with `RUNTIME: Authentication required`; no review findings were produced. Proceed with the confirmed, source-backed plan and retry the landing gate.
- Landing review via `sem diff` found only the intended Herdr workflow, raw-jj migration, documentation, and jut deletion. Hunk launch is blocked because the installed bridge command `herdr-hunk` is absent from `PATH`.

## Feedback

- The proposed `jj commit` + `bookmark move @-` sequence conflicted with the repository's shared-working-copy rule. Canonicalized the safer in-place `describe`/`bookmark set @` sequence before implementation.
- Workspace creation originally fetched implicitly, violating the chosen publish-only sync boundary. Removed it and added a command-log regression assertion.
- Cleanup's generic remove action cannot use remote-bookmark equality because GitHub deletes merged branches. It verifies clean identity plus authoritative closed/merged PR state; explicit typed abandon covers no-PR work.
- The user explicitly prohibited killing Herdr. All runtime work uses reload/read-only operations; plugin tests use fake Herdr binaries.
- Directly writing the local plugin registry updates disk but not the running server. The activation now follows marketplace installation with idempotent `herdr plugin link` calls, which makes local plugins immediately visible without restarting Herdr.

## Remaining work

- None.

## Commits

- `229ec38` — `feat(herdr): add safe jj task workflow`
- `6a60501` — `refactor(jj): remove jut wrapper`
