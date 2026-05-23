# Agents Module Directory

This directory contains Nix modules for AI agents:

- `agentsview/` - agentsview TUI from numtide/llm-agents.nix
- `claude/` - Claude Code CLI (Anthropic)
- `codex/` - Codex CLI (OpenAI)
- `hermes/` - Hermes agent CLI (local development)
- `opencode/` - OpenCode CLI
- `packages.nix` - Simple agent-adjacent package toggles such as `gnhf`
- `pi/` - Pi coding agent + shell helpers (worktree management, PR review)

## Option Namespace

All modules live under `modules.agents.*`:

```nix
modules.agents = {
  agentsview.enable = true;
  claude.enable = true;
  codex.enable = true;
  gnhf.enable = true;
  hermes = {
    enable = true;
    secretReferences = { ... };
  };
  opencode.enable = true;
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

## Module Boundaries

These modules are for AI coding agents only. Do NOT put:

- Shell tools here (see `modules/shell/`)
- System services here (see `modules/services/`)

## Adding a New Agent

1. Create `modules/agents/<name>/default.nix`
2. Use `options.modules.agents.<name>` as the option namespace
3. Wire shared rules from `config/agents/rules/` (same pattern as claude/codex)
4. Enable in host configs under `modules.agents.<name>.enable = true`
5. Update this AGENTS.md
