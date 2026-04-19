# Claude Code Configuration

## Purpose

This directory now holds only the Claude-specific pieces that are still worth keeping around when most shared agent behavior lives in `config/agents/`.

## Contents

- `settings.json` - Claude runtime settings used by native Claude Code and `acpx claude`
- `plugins/claude-lint/` - local plugin source for plugin validation
- `plugins/github/` - local plugin source for PR review commands
- `plugins/json-to-toon/` - local plugin source for prompt compression

## Shared elsewhere

- Skills: `config/agents/skills/`
- Modes/agents: `config/agents/modes/`
- Rules/instructions: `config/agents/rules/`

`modules/agents/claude/default.nix` wires those into `~/.claude/`.
