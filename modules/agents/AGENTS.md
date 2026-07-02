# Agents Module Directory

This directory contains Nix modules for AI agents:

- `agentsview/` - agentsview TUI from numtide/llm-agents.nix
- `claude/` - Claude Code CLI (Anthropic)
- `codex/` - Codex CLI (OpenAI)
- `hermes/` - NixOS-only Hermes Gateway/runtime host wiring
- `omp/` - Oh My Pi CLI, isolated from Pi's `~/.pi/agent`
- `opencode/` - OpenCode CLI
- `pi/` - Pi coding agent + shell helpers (worktree management, PR review)

## Option Namespace

All modules live under `modules.agents.*`:

```nix
modules.agents = {
  agentsview.enable = true;
  claude.enable = true;
  codex.enable = true;
  hermes = {
    enable = true;
    secretReferences = { ... };
  };
  opencode.enable = true;
  omp.enable = true;
  pi = {
    enable = true;
    honcho.enable = true;
    memoryRemote = "git@github.com:edmundmiller/pi-memory";
  };
};
```

## Shared Config Source

Agents (claude, codex, opencode) share a single source of truth in `config/agents/`:

- `config/agents/rules/` - Shared rules/instructions (concatenated into each agent's config)
- `config/agents/modes/` - Shared agent mode definitions

Global skills live in `~/.agents/skills/` and are discovered natively.

## Agent Runtime Drift Hooks

Warning-only prek `pre-push` hooks check mutable runtime state for agent drift:

- `pi-runtime-drift` checks `~/.pi/agent` for dirty git extension caches and obvious Pi binary/settings drift.
- `hermes-runtime-drift` checks managed `$HERMES_HOME` for stale repo-managed Hermes config, SOUL, skins, hooks, and plugins.

These hooks must never mutate runtime state or block pushes for drift. Fix warnings with the appropriate rebuild/update command, usually `hey re` and, for Pi extensions, `pi update --extensions`.

## Herdr Integration

When `modules.shell.herdr.enable = true`, the Herdr shell module automatically installs Herdr integrations for enabled agent modules during activation. Agent modules should create/bootstrap their runtime config directories before Herdr's activation step, but they do not need to call `herdr integration install` themselves.

## Module Boundaries

Hermes boundary:

- `modules.agents.hermes` is NixOS-only host wiring for declarative Hermes Gateway/runtime setup.
- macOS Hermes Desktop installs are intentionally outside this repo module for now.
- Reusable Hermes profile/preset logic belongs in `agents-workspace`; dotfiles selects and wires host-specific deployment choices.

These modules are for AI coding agents and managed agent runtimes only. Do NOT put:

- Shell tools here (see `modules/shell/`)
- System services here (see `modules/services/`)

## Adding a New Agent

1. Create `modules/agents/<name>/default.nix`
2. Use `options.modules.agents.<name>` as the option namespace
3. Wire shared rules from `config/agents/rules/` (same pattern as claude/codex)
4. Enable in host configs under `modules.agents.<name>.enable = true`
5. Update this AGENTS.md
