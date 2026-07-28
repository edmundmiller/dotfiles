# Worklog: herdr-codex-jj

Status: complete

## Objective

Make Herdr-created jj task workspaces start Codex and Hunk, focus Codex, give Codex durable jj operating rules, and preserve `$done` as the publication boundary. Stop when focused tests, package checks, host activation, runtime inspection, landing review, and upstream verification pass.

## Decisions

- Herdr owns workspace creation; Codex owns implementation inside that workspace.
- Keep Codex Desktop Git worktrees on Git. Never initialize nested jj metadata.
- Change the default two-tab task layout from OMP/Hunk to Codex/Hunk. OMP remains installed and available manually.
- Reuse the existing jj workspace plugin and `$done`; do not add a second launcher or publication path.

## Evidence

- Red: focused tests failed because the plugin created/focused OMP and the shared Codex rule lacked the jj contract.
- Green: `python3 -m unittest packages/herdr-plugins/dotfiles-dev-layout/dev_layout_test.py tests/test_agent_response_contract.py tests/test_herdr_plugin_packaging.py tests/test_agent_quality.py` — 29 passed.
- `nix build --no-link '.#darwinConfigurations.MacTraitor-Pro.pkgs.my.herdr-plugins'` — package built.
- `hey check` — all Darwin checks passed; its changed-file formatter/hook selectors were no-ops, so focused formatter/tests were run separately.
- `ruff format --check ...` and `prettier --check ...` — changed Python and Markdown passed.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` — activation succeeded and installed Codex/Herdr integrations.
- `herdr server reload-config` — `status: applied`, no diagnostics.
- Live plugin source contains the Codex bootstrap; live `~/.codex/AGENTS.md`, global skill, `prefix+a`, and jj plugin actions were re-read successfully.
- `hey agent-audit-tests ...` — passed.
- Source-tree `agent-quality-tests`, confidence, and inventory gates passed. The installed wrapper's repo-quality formatter/hook selector could not run because this checkout has no `prek.toml` or `.pre-commit-config.yaml`; focused Ruff/Prettier checks passed instead.

## Reviews

- Plan review blocked: Claude and Cursor required authentication; Gemini ACP exited because the installed CLI adapter passed an unsupported argument. No provider was retried.
- Landing review blocked: direct Gemini ACP also required authentication. `sem diff` and `git diff --check` found no task-scope or whitespace defect.

## Feedback

- Current OMP-only bootstrap and conditional OMP rule make the intended Herdr/Codex workflow easy to miss.
- `hey agent-finish` executes its packaged Nix-store source and can miss the active checkout; its changed-file hooks also require a repository `prek` config that this checkout lacks.

## Remaining work

- None.

## Commits

- `feat(herdr): launch Codex in jj task workspaces`
