# Worklog: herdr-0.7.5-agent-automation

Status: complete

## Objective

Bump the repo-managed Herdr package from 0.7.4 to 0.7.5 and align every maintained Herdr automation surface with the official agent-automation contract. Stop only when the patched package builds, focused checks pass, the Darwin host is activated, the installed CLI reports 0.7.5 with the documented command shapes, and the task-shaped commits are current upstream.

## Decisions

- Treat the supplied `https://herdr.dev/docs/agent-automation/` page and the installed 0.7.5 CLI as the automation sources of truth.
- Preserve the unrelated dirty changes already present in `.agents/worklogs/herdr-crash-tdd.md`, `config/agents/rules/15-agent-behavior.md`, and `openwiki/services-and-agents.md`.
- Do not control live Herdr topology from this pane because `HERDR_ENV` is unset; verify package/runtime state through the binary, config, server, and focused disposable checks instead.
- Register local and marketplace plugins through Herdr's 0.7.5 user-global CLI registry with a deliberately offline socket. This avoids hand-serializing schema and prevents an older live server from causing an activation-time protocol mismatch.
- Remove downstream cursor/scrollback patch 0010 because the exact guard and regression test are upstream in 0.7.5; rebase the still-needed resize patches instead.

## Evidence

- `hostname` -> `MacTraitor-Pro.local`; `uname -a` -> Darwin arm64.
- `herdr --version` -> `herdr 0.7.4` before the bump.
- GitHub release API -> v0.7.5 published 2026-07-21 at commit `ef4c23f5775bb8cfec05f05d0844226ff959a07a`.
- Exact automation page extracted with `defuddle parse ... --md`; it documents existing-pane `agent start`, `agent prompt`, `agent send-keys`, and `pane wait-output`.
- Overlay source prefetch -> `sha256-3BA8eredGku+vsL2Af7sUf43QiArR5XTHNrI+X11vFM=`; Nix evaluated the fully patched source at `/nix/store/mq42yi5y0qf4z9cibz1bs38a7hzclfh6-source`.
- Fresh upstream patch application -> patches 0001, 0006, 0007, 0008, 0009, 0011, and 0012 apply in order; 0010 is no longer present.
- Automation audit migrated the conditional Herdr skill and helpers, `dotfiles.dev-layout`, `dotfiles.agent-read-command`, `pi-herdr`, and the stale `pi-hunk` compatibility-helper call.
- `./bin/herdr-self-test` -> 23 Python tests and 10 Bun tests pass across the maintained skill, plugin, Pi, and helper surfaces.
- `bun run --cwd packages/pi-packages/pi-herdr check` and `bun run --cwd packages/pi-packages/pi-hunk check` -> TypeScript checks pass.
- Skill validator -> `{"checked": 1, "findings": []}`.
- `nix build .#herdr --no-link --print-out-paths` -> `/nix/store/mayi5mnhk7aqkrfj379cnf2n7zdyhh9p-herdr-0.7.5`; the result reports `herdr 0.7.5` and exposes the documented agent and pane command groups.
- `nix build .#herdr-plugins` plus a disposable HOME/offline socket -> all three packaged local plugins link and list with their full 0.7.5 registry schema.
- `hey check --worktree ...` -> Darwin evaluation, formatting, hooks, tmux, package harness/policy, and AST checks pass; `hey agent-audit-tests ...` -> `PASS test-confidence`.
- Three exact `darwin-rebuild switch --flake .` activations completed, including a final switch after the Pi extension audit. The real activation linked local plugins offline, found all marketplace plugins, and installed Pi, Claude, Codex, OpenCode, and OMP integrations.
- Post-switch installed client -> 0.7.5/protocol 17; writable config -> `config: ok`; duplicate unmanaged `prefix+t` blocks are now deterministically reduced to one while preserving the user command.
- Deployed OMP plugin symlink -> `/nix/store/zskv04qf6cvvnxb14zsn9py4p7clm3q8-pi-herdr`; it contains the 0.7.5 detection-read routing and the installed offline registry lists `dotfiles.dev-layout` 0.2.0 with minimum Herdr 0.7.5.
- The running server remains 0.7.4/protocol 16 with `restart_needed: yes`. This pane is not Herdr-managed, so the skill's session guard forbids restarting or handing off the live topology from here.

## Reviews

- Plan review: `hey agent-review plan --active-model-family gpt-5 ...` stopped before producing findings with `RUNTIME: Authentication required`.
- Landing review: `hey agent-review landing --active-model-family gpt-5 ...` stopped before producing findings with `RUNTIME: Authentication required`.

## Feedback

- `fff` and `pkg-list` are not on the ambient PATH in this shell; use the repo development shell where available.
- The prior `bin/herdr-self-test` still targeted helper binaries deleted by the June plugin migration. It now runs the maintained integration suites.
- `pi-hunk` still invoked deleted `herdr-hunk`; regression commit `f9ea1b161` captures the failure before the pane-API fix.
- Herdr 0.7.5's config validator exposed two identical unmanaged `prefix+t` command blocks in the writable runtime config. Regression commit `35b86083c` executes the real bootstrap program against that shape.

## Remaining work

- User action only: restart Herdr from inside the managed session so the live server advances from 0.7.4 to 0.7.5.

## Commits

- `f9ea1b161 test(pi-hunk): capture removed Herdr helper regression`
- `35b86083c test(herdr): capture duplicate writable keybindings`
- `8651cece5 chore(herdr): bump to 0.7.5`
- `00196754d feat(herdr): adopt 0.7.5 agent automation`
- Annotated landing tag: `agent-work/herdr-0.7.5-agent-automation`
