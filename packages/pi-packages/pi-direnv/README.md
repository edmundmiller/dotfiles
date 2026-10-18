# pi-direnv

Load trusted mise environments at session start and when switching sessions,
with [direnv](https://direnv.net/) fallback for projects using `.envrc`.

## Install

```bash
pi install npm:pi-direnv
```

## What it does

On `session_start` and `session_switch`, including switches requested by the RPC `switch_session` command:

1. Restores variables changed by the previous load, including PATH.
2. Searches from `ctx.sessionManager.getCwd()` up to the git root for mise
   configuration, regardless of where Pi was launched. Without a Git root,
   the search stops before the home directory. Falls back to `.envrc` only
   when no project mise configuration exists.
3. Uses `mise exec` to read a child environment as JSON, without running tasks,
   installing tools, or entering a Nix shell. Trust remains required even in CI
   or when the parent sets `MISE_YES`. Otherwise uses `direnv export json`.
4. Applies the environment only after a successful command and valid JSON.
   Direnv null values remove variables. Failed loads retain the restored baseline.
5. Warns on failure without displaying environment values or subprocess output.

Review and explicitly trust project configuration yourself. Mise uses paranoid
trust checks; edits may require running `mise trust` again. Trusted mise env
templates and direnv scripts still execute their configured code. This extension
does not sandbox them. Mise 2026.7.5 does not apply `[env] KEY=false` in `exec`;
the loader follows that upstream limitation, but always removes its own prior
project exports on session switches.

## Why

Pi launched outside a project still needs that session's PATH and environment.
Loading dotfiles' mise configuration stays lightweight; run `mise run dev`
explicitly when a Nix shell is needed.

Inspired by [simonwjackson/opencode-direnv](https://github.com/simonwjackson/opencode-direnv).
