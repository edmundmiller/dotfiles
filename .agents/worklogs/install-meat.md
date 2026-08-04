# Worklog: install-meat

Status: complete

## Objective

Install `boldsoftware/meat` declaratively on the current Darwin host. Stop when a fresh managed shell resolves `meat`, the executable passes a real smoke check, and the change is committed, pushed, and verified against `origin/main`.

## Decisions

- Preserve the dirty canonical checkout by working from a clean sibling worktree based on `origin/main`.
- The pinned nixpkgs set has no `meat` attribute, so add a repository-local `buildGoModule` package pinned to upstream commit `f39f41dfe7b5b37a12b35fdfbaecc7e779855bd3`.
- Install `pkgs.my.meat` only on MacTraitor-Pro, matching the user's current host and avoiding an unrequested cross-host rollout.
- Wrap the executable with Git on `PATH`; `meat` shells out to Git for its primary inputs.
- Do not invent or persist an API credential. The CLI supports `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`, but neither is currently present and 1Password is locked.

## Evidence

- Source request: https://x.com/tqbf/status/2084329402079363270 and https://github.com/boldsoftware/meat
- Host: `MacTraitor-Pro.local`, Darwin arm64.
- `nix eval --raw '.#darwinConfigurations."MacTraitor-Pro".pkgs.meat.version'` failed with no package attribute.
- Upstream `go.mod` declares Go 1.24.13 and no third-party module dependencies.
- Red test: `uv run --with pytest pytest tests/test_meat_package.py -q` failed because `packages/meat/default.nix` did not exist.
- Green test: `uv run --with pytest pytest tests/test_meat_package.py -q` passed.
- `nix develop -c pkg-check meat` cloned the pinned commit, passed both upstream Go packages, and exercised `go run ./cmd/meat -h`.
- `nix build .#meat --no-link` passed; the installed wrapper puts Nix Git on `PATH`.
- `nix eval` confirmed `meat` is in MacTraitor-Pro's system package list.
- `nix develop -c ast-grep scan packages/meat` passed.
- Scoped `hey check --worktree ...` passed Darwin evaluation, formatting, hooks, package harness/policy, tmux, and ast-grep checks.
- After rebasing onto the current `origin/main`, the regression test, `pkg-check meat`, `nix build .#meat --no-link`, the package structural scan, and scoped `hey check` all passed again.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` activated successfully.
- A fresh login shell resolves `/run/current-system/sw/bin/meat`, whose real path is the pinned Nix store package; `meat -h` passed.
- A model-backed call correctly stops before network access because no supported credential is currently exposed: `no OpenAI credentials`.

## Reviews

- The default Claude plan reviewer and Gemini fallback both returned `RUNTIME: Authentication required`.
- The Pi plan reviewer never returned output and left a stale ACP process; that process was terminated before retrying.
- The Pi landing reviewer remained idle with 0% CPU and no output for more than two minutes, then was terminated. No code finding was reported, but the heterogeneous landing gate is not proven.
- The final landing retry again failed before review with `RUNTIME: Authentication required`; the OpenCode fallback also failed before initialization because its postinstall runtime is missing. Manual semantic and whitespace review found only the requested package, host install, regression test, and this worklog.

## Feedback

None.

## Remaining work

- A real abridgement needs `OPENAI_API_KEY`, `OPENAI_BASE_URL`, or an Anthropic equivalent in the invoking environment; no supported credential is currently exposed on this host.

## Commits

- `feat(darwin): package and install meat`
