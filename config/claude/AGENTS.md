# Claude Code Configuration

## Purpose

This directory now holds only the Claude-specific pieces that are still worth keeping around when most shared agent behavior lives in `config/agents/`.

Unlike most `config/` files, `settings.json` is a template: `modules/agents/claude/default.nix` bootstraps it into a writable `~/.claude/settings.json` and preserves runtime-managed hooks such as Herdr's Claude integration.

## Contents

- `settings.json` - Claude runtime settings template used by native Claude Code and `acpx claude`
- `plugins/claude-lint/` - local plugin source for plugin validation
- `plugins/github/` - local plugin source for PR review commands
- `plugins/json-to-toon/` - local plugin source for prompt compression

## Shared elsewhere

- Skills: `skills/catalog/`
- Modes/agents: `config/agents/modes/`
- Rules/instructions: `config/agents/rules/`

`modules/agents/claude/default.nix` wires those into `~/.claude/`.
