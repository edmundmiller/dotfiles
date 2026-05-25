# Claude CLI Module - Agent Guide

## Purpose

Minimal Nix module for Claude Code. It keeps Claude pointed at the shared rules, modes, and skills layout while preserving a small amount of Claude-specific runtime config.

## Key paths

- `modules/agents/claude/default.nix` - module definition
- `config/claude/settings.json` - Claude-specific settings template
- `config/agents/rules/` - source for `~/.claude/CLAUDE.md`
- `config/agents/modes/` - source for `~/.claude/agents/`
- `config/claude/plugins/` - repo-local Claude plugin sources

## Facts

- Enable with `modules.agents.claude.enable = true`
- `~/.claude/skills` is a bridge to `~/.agents/skills`
- `~/.claude/settings.json` is bootstrapped as a writable local file, not a Home Manager symlink, so runtime integrations such as Herdr can mutate Claude hooks.
- Plugins are user-installed; this repo only keeps source trees and settings
- WakaTime config is Darwin-only and depends on `wakatime-api-key`
