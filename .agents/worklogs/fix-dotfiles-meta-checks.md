# Worklog: fix-dotfiles-meta-checks

Status: complete

## Objective

Make the repository-owned hook configuration and installed `hey agent-finish`
launcher work from a clean checkout without bypass variables. Stop only after
focused regression tests, real `hey check`, real `hey agent-finish`, landing on
`main`, push, and remote-equality proof all pass without changing Home Assistant
climate behavior.

## Decisions

- Start `codex/fix-dotfiles-meta-checks` at fetched `origin/main`
  `c2b411ce3740660145b9b7e7bc0c6e06f60717a4`.
- Preserve all unrelated worktrees and Home Assistant behavior.
- Use red/green tests before changing hook or launcher behavior.
- Agent CI is not run because its skill reserves the full local CI pipeline for
  explicit requests; focused checks plus the requested real `hey` gates apply.
- Keep `flake.nix` as the single hook-config source. Expose its generated
  `config.pre-commit.settings.configFile` as a flake package, pass that immutable
  path explicitly from `hey check`, and install shared hooks against the same
  absolute path.
- Make the installed quality launcher default `AGENT_QUALITY_ROOT` to the
  caller's Git checkout, while preserving an explicit caller override; package
  Jujutsu with `pkgs.jujutsu`.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin 27.0.0 arm64.
- Git backend confirmed; assigned checkout is clean and has no active rebase.
- `origin/main`, local `main`, and starting HEAD matched at
  `c2b411ce3740660145b9b7e7bc0c6e06f60717a4`.
- Changed-file reproduction: `env -u PREK_ALLOW_NO_CONFIG hey check --worktree
tests/meta-check-reproduction.txt` failed both formatter and hook phases with
  `No prek.toml or .pre-commit-config.yaml`; the temporary probe was deleted.
- Installed reproduction: `env -u AGENT_QUALITY_ROOT -u PREK_ALLOW_NO_CONFIG
hey agent-finish --worklog ...` emitted `git diff --cached` and not-a-repo
  errors from `/nix/store/...-source`, then failed the jj workspace test.
- Direct `jj git init --colocate` succeeds because the interactive PATH resolves
  Jujutsu. The package uses `pkgs.jj`, the unrelated JSON stream editor.
- `.pre-commit-config.yaml` was deliberately removed and ignored in
  `13f965f53`; `git-hooks.nix` still generates the authoritative config as a Nix
  store file, but the shell-installed shared shim records a checkout-relative
  `--config=.pre-commit-config.yaml`.
- The installed launcher unconditionally exports
  `AGENT_QUALITY_ROOT=${../../..}`, pinning all manifests, diffs, and tests to
  its immutable source closure instead of the caller checkout.
- Red: both regression tests failed against the original source. Test commit
  passed with two strict expected failures. Green: all 17 agent-quality tests
  pass after the repair.
- `nix build .#pre-commit-config --no-link --print-out-paths` returned the
  generated store config; `nix develop` removed the checkout-local config and
  installed all shared hooks with that absolute path.
- `env -u PREK_ALLOW_NO_CONFIG ./bin/hey check --worktree` passed formatting,
  hooks, Darwin evaluation, tmux tests, package tests, and ast-grep tests.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` built and
  activated the committed `hey` and `agent-quality` packages successfully.
- Installed `env -u PREK_ALLOW_NO_CONFIG hey check --worktree` passed every
  Darwin check with six changed paths and no checkout config.
- Installed `env -u AGENT_QUALITY_ROOT -u PREK_ALLOW_NO_CONFIG hey
agent-finish --worklog ...` passed repo quality, all 17 agent-quality tests,
  confidence, inventory, and worklog validation. The jj workspace test used
  `/private/tmp` successfully; no Git/Nix-store-root errors occurred.
- Waited for the owning Buzz Codex task to finish and push. Rebasing onto
  `origin/main` `9dff7b279` was conflict-free; all 17 focused tests and the
  source `./bin/hey check --worktree` passed.
- Buzz's later Darwin activation reproduced the installed missing-config
  failure because it deployed pre-repair `main`. Activating this rebased branch
  restored the installed launcher, and `env -u PREK_ALLOW_NO_CONFIG hey check
--worktree` passed every Darwin gate.
- The existing default checkout retains only unrelated Herdr edits. Landing
  uses this clean task checkout and a fast-forward remote-main push without
  modifying those files.

## Reviews

Plan review attempted with Claude through ACPX; `session/new` returned
`RUNTIME: Authentication required`. One Gemini fallback exited before
initialization because the installed CLI rejected ACPX's `acp` argument. The
heterogeneous plan gate is unverified with exact provider blockers recorded.
Landing review with Claude reached `session/new` and returned the same
`RUNTIME: Authentication required`; no review findings were available.

## Feedback

- Repeated worklogs show the ignored hook-config symlink and wrong installed jj
  package have caused cross-task bypasses and false failures; both need
  executable regression coverage rather than another workaround note.

## Remaining work

None.

## Commits

- `fbb165ba8 test(meta): cover hook and agent-quality drift`
- `bb49e0bbd fix(meta): repair hook and agent-quality ownership`
- Worklog checkpoint commits.
