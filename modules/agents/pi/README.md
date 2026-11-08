---
purpose: Configure and verify the Nix-managed Pi daily-driver environment.
applies_to: Pi upgrades, native MCP, codemode, and shell helpers.
entrypoint: Edit config/pi/settings.jsonc and overlays/pi/default.nix.
verification: Build .#pi, run Pi settings checks, and inspect pi mcp list.
update_when: Pi packaging, MCP ownership, or Herdr integration changes.
---

# Pi Module

Pi coding agent configuration plus shell helpers for common local workflows.

## Default behavior

`config/pi/settings.jsonc` keeps model/UI preferences and integrations while
leaving compaction, retries, message delivery, images, and skills at Pi defaults.
The shared core remains the only global instruction file.

`pi-goal-x` owns `/goal`, `/sisyphus`, persistent progress, and optional completion
auditing on every Pi-enabled host. It continues confirmed active goals automatically.
Use `/goal-pause` to stop and `/goal-settings` to configure its behavior.

Other default packages exclude automatic loop continuation, model switching,
response coaching, Agentmap/QMD prompt injection, and DCP/RTK/read rewriting.
Permissions, command policy, signing protection, `pi-memory`, host integrations,
and explicit review/handoff commands remain available. `contextMemory.enable`
defaults to false; it opts into the additional `pi-context` package, not `pi-memory`.

Feynman's research workflows and Confluence CLI's usage skill are intentional
package-native resources. Session Hoarder archives sessions locally by default.
Plannotator comes from its owning module.
Existing Hermes memory files are retained, but `pi-memory` does not read them.

This is not a hook-free setup. `pi-markdown-workflows` retains nested AGENTS.md
discovery and also injects automatic workflow-selection guidance in projects
with `.pi/workflows`. Browser activation, memory, and permission hooks remain.
The image helper preserves attachments without modifying the system prompt.
`/goalize` is an explicit task-framing prompt, not a persistent goal service.

Use `modules.agents.pi.extraPackages` for deliberately opted-in packages rather
than growing the shared defaults. Local package sources remain available for
that purpose. Existing sessions retain their earlier context; test in a fresh
session after an authorized `hey re` applies the managed settings and links.

## Command approvals

The shared settings load `@gotgenes/pi-permission-system@42.0.0` as the sole
command permission layer. The module renders
`config/pi/pi-permission-system.jsonc` as strict JSON at the package's default
configuration path. Upstream owns approval dialogs, session approvals, and
`yoloMode` behavior. No custom command-policy or commit-signing gate is loaded.
Git still enforces its configured commit signing.

Home Manager owns the policy file and reclaims it on activation if the upstream
settings UI replaced its symlink. Runtime toggle changes do not survive that
activation. Source edits require an authorized rebuild and a Pi reload or fresh
session before running agents adopt them.

## Project environment

Pi inherits its launch environment. The `pi-direnv` package is disabled by
default, so Pi does not automatically import mise or direnv exports on session
start or switch. Normal shell mise integration is unchanged. Launch with
`mise exec -- pi` when a project needs its mise environment. Restart Pi from a
fresh shell to discard exports an earlier loader may already have injected.

## Pi 1.0 and native MCP

`overlays/pi/default.nix` selects an independently pinned upstream Pi package.
This includes the codemode worker and native platform assets without upgrading
the other agents in the shared `llm-agents` input. Check the effective version
with `nix eval --raw .#pi.version`, then build with `nix build .#pi`.

Pi 1.5.0 uses the upstream build recipe with local `overlays/pi/hashes.json`
and `package-lock.json` pins. The wrapped CLI defaults `PI_SELF_UPDATE_COMMAND`
to a packaged script that selects the dotfiles checkout and runs `mise run pi:update`.
When Pi detects a newer release, `pi update` refreshes only these Pi pins,
then runs the guarded rebuild task.
An explicit `PI_SELF_UPDATE_COMMAND` environment value overrides that default.
Use `pi update --extensions` to update extensions without rebuilding the host.

The packaged self-update script targets `$FLAKE_DIR`, then `$DOTFILES`, then
`~/.config/dotfiles`, not the current project's flake. It appends packaged
tools and then the active system tools to its own PATH for GUI/service launches,
preserving caller tool precedence without loading a user profile. A direct
`hey pi-update <version>` runs the current checkout's task, like every other
`hey` command. The updater rejects downgrades
and leaves the pins unchanged if downloading or preparing dependencies fails.
A failed rebuild leaves the new pins available for inspection and retry with
`hey re`. Revert both Pi pin files and run `hey re` to return to an earlier release.
Running a self-update activates the host configuration, so agents still need
explicit authorization. Source checks do not run this command.

The launcher pins the tools used before crossing the host activation boundary:

| Command path                             | Packaged executables                                               |
| ---------------------------------------- | ------------------------------------------------------------------ |
| Task dispatch and host context           | `bash`, `mise`, `nu`, `hostname`, `nix`, coreutils including `env` |
| Lock and tracked-file guards             | `grep`, `jq`, `git`                                                |
| Darwin GitHub authentication             | `gh`                                                               |
| Archive/build and Homebrew-process check | `bash`, `nix`, `ps`, `awk`                                         |

`pi.updater` separately packages Python, Node/npm and `prefetch-npm-deps`.
The active host supplies privileged `sudo`, `darwin-rebuild` or `nixos-rebuild`,
the optional NUC `nix-private-github` credential wrapper, and Linux `systemctl`.
Darwin uses `/usr/bin/sudo`; the launcher leaves these commands and credentials
under host configuration. Authentication failure retains the existing Nix config;
an archive failure stops activation. Pin updates happen before rebuild guards,
so a guard failure can leave updated pins for inspection without activating them.

The Nix `validation-tests` check executes the packaged launcher with a minimal
PATH and real lock/auth/rebuild logic in a disposable checkout. It remaps host
paths and platform identity only in that fixture and mocks updater, network and
activation boundaries. It does not certify native sudo, keychain or activation.

`config/pi/settings.jsonc` enables codemode alongside the ordinary tools.
The host catalog in `modules.agents.mcp` supplies native MCP registrations in
writable `~/.pi/agent/mcp.json`, with tools available through codemode rather
than loading every tool into each prompt. GitHub's stdio launcher reads
`gh auth token` at process start. Linear needs a one-time
`pi mcp login linear`; its credentials stay in writable `~/.pi/agent/mcp-auth.json`.
Use `pi mcp list` and `/mcp` to check connections.

Edit catalog-owned registrations in the host configuration. Reconciliation
preserves unrelated servers and settings; matching catalog names are host-owned.
Project-specific servers can live in `.pi/mcp.json` after project trust.
`modules.agents.mcp.agents.pi = false` removes host-managed Pi registrations;
it does not disable project MCP servers. See [ADR 0013](../../../docs/adr/0013-host-owned-agent-mcp.md)
for ownership and the focused adapter test.
Do not reinstall `pi-mcp-adapter`: its `/mcp` command replaces native MCP.

Hosts with Herdr 0.7.5+ use `@ogulcancelik/pi-herdr@0.4.0` for pane/layout/agent
tools and the activation-installed lifecycle extension. Herdr 0.9.1 and 0.9.3 ship
the same Pi integration version 9. Check the installed marker with
`rg HERDR_INTEGRATION_VERSION ~/.pi/agent/extensions/herdr-agent-state.ts`.
Hosts below Herdr 0.7.5 retain plugin 0.2.5 as a compatibility fallback.

The repository's `pi-herdr` package supplies only `/review-box` and
`herdr_pr_review_workspace`. General layout, pane, and agent tools come from
the official plugin; Review Box persistence and approval behavior stay local.

## Shell Helpers

The zsh module auto-sources `config/pi/aliases.zsh`, which provides:

| Helper                    | Description                                                                                                                                                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `piw [name] [pi args...]` | Create a git worktree under `.pi/worktrees/`, `cd` into it, and launch the real `pi`. Omitting `name` auto-generates one. Use `piw -- "prompt"` when you want an auto-generated name plus a prompt.                       |
| `pir [pr] [pi args...]`   | Without a PR number, review the current checkout against `origin/main`. With a PR number, show quick PR context with `gh pr view`, run `gh pr checkout`, then launch the real `pi` with a default review-oriented prompt. |

These helpers intentionally avoid shadowing the packaged `pi` binary.
