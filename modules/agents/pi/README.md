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
Plannotator comes from its owning module, and `pi-btw` remains a shared package.
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

## Pi 1.0 and native MCP

`overlays/pi/default.nix` selects an independently pinned upstream Pi package.
This includes the codemode worker and native platform assets without upgrading
the other agents in the shared `llm-agents` input. Check the effective version
with `nix eval --raw .#pi.version`, then build with `nix build .#pi`.

`config/pi/settings.jsonc` enables codemode alongside the ordinary tools.
`config/pi/mcp.json` supplies GitHub and Linear through native MCP, with tools
available through codemode rather than loading every tool into each prompt.
GitHub uses the current `gh auth token` at runtime. Linear needs a one-time
`pi mcp login linear`; its credentials stay in writable `~/.pi/agent/mcp-auth.json`.
Use `pi mcp list` and `/mcp` to check connections.

The MCP configuration is Nix-managed. Edit its repo source rather than running
`pi mcp add` against the read-only global file. Project-specific servers can
live in `.pi/mcp.json` after project trust. `modules.agents.pi.mcp.enable = false`
omits the managed global server file; it does not disable project MCP servers.
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
