# Worklog: herdr-vercel-sandbox-mtp

Status: complete

## Objective

Install and configure the Vercel Sandbox Herdr plugin declaratively on MacTraitor Pro, select Codex as the Sandbox agent, rebuild the host, and prove the live plugin actions and configuration are available. Stop only at authentication or per-repository linking that requires the user.

## Decisions

- Keep Herdr plugin installation and keybindings in their existing Nix-managed sources.
- Do not copy host credentials into a Sandbox; use the supported interactive Vercel and Codex authentication flows.
- Preserve unrelated untracked worklog and Beads files.

## Evidence

- Preflight: `MacTraitor-Pro.local`, Darwin arm64, Herdr 0.8.0, Node 22.22.3, Git 2.54.0.
- Vercel CLI 50.13.2 was below the plugin's documented minimum 56.2.0 and had no local credentials.
- Red/green: the new focused packaging test failed before implementation, then `uv run --with pytest pytest tests/test_herdr_plugin_packaging.py -q` passed 10 tests.
- `nix build .#checks.aarch64-darwin.herdr-config-check --no-link` passed.
- `hey check` passed all Darwin checks.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` completed and installed Vercel CLI 58.9.0 plus `vercel.sandbox` at commit `be8393aac17eae4b67ca58fdcc5ad8233f91b6c5`.
- Live proof: `herdr config check` returned `config: ok`; reload returned `status: applied`; all nine upstream plugin actions were listed; managed Codex config and the five MTP shortcuts were present.
- The upgraded `vercel whoami --format json` diagnostic waited on macOS credential storage and was stopped without bypassing authentication.

## Reviews

None requested.

## Feedback

- `hey agent-finish` could not make the repository-wide quality gate green because unrelated untracked `.agents/worklogs/audit-agent-worktrees.md` is 1261 KB, above the 500 KB large-file limit. It was preserved untouched; task-focused checks and the live runtime verification passed.

## Remaining work

- User must complete the official Vercel login, then run `vercel link` once in each intended Git worktree. Codex authentication remains inside its persistent Sandbox.

## Commits

- `feat(herdr): add Vercel Sandbox agents on MTP`
